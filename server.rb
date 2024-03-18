# 17. modeleur_cookie (basé sur modeleur0.8-smart)

require 'rubygems'
require 'sinatra'
require 'sinatra/cookies'
require 'rexml/document'
require 'nokogiri'

include REXML

# set :bind, '192.168.1.25' # à enlever dans la version heroku

enable :sessions



#-------------------------------------------------
# Methods
#-------------------------------------------------
def serial_vers_profils(serial)
	serial_cnf = "./cnf/" + serial + ".cnf3"
	doc_cnf = Nokogiri::Slop(File.read(serial_cnf)) 
	tableau_des_profils = doc_cnf.DonnesDeConfiguration3.DonneesDeChampsProfil.DonneesDeChampProfil
	return tableau_des_profils
end

def profils_vers_dossiers(tableau_des_profils)
	tableau_des_dossiers = Array.new
	for profil in tableau_des_profils
		raccourci = profil.AffichageRaccourci.content
		space_index = raccourci.index(' ') + 1
		dossier = raccourci[space_index..]
		tableau_des_dossiers << dossier unless tableau_des_dossiers.include? dossier
	end
	return tableau_des_dossiers
end

def getserial(xmlstr)
	model_serial = get_model_serial_from(xmlstr)
	return model_serial[:serial]
end
		
def build_iojob(endpoint, phase=nil)
    @prmtr = Hash.new
    #@prmtr[:cmds] = []           
    case endpoint
    when "init"
		#puts "=== étape 1 === init ==="
		#puts "vieux cookie : "
		#puts cookies["serial"]
		@prmtr[:getserial] = Hash.new
		@prmtr[:getserial][:submit] = "/readcnf"
		#@prmtr[:cmds] << :getserial
        return erb :getserial #:multicommand
   
    when "readcnf"
		#puts "=== étape 2 === readcnf ==="
		xmlstr = params[:xml].to_s 
		num_ser = getserial(xmlstr)
		#puts "connecté : " + num_ser
		tableau_des_profils = serial_vers_profils(num_ser)
		tableau_des_dossiers = profils_vers_dossiers(tableau_des_profils)
		nombre_dossiers = tableau_des_dossiers.length
		#puts nombre_dossiers
		#response.set_cookie("serial", { :value => num_ser, :expires => (Time.now + 3600), :path => '/' })
		cookies["serial"] = num_ser
		#response.set_cookie("number", { :value => nombre_dossiers, :expires => (Time.now + 3600), :path => '/' })
		cookies["number"] = nombre_dossiers
		#puts "cookies dans la boite"
		if nombre_dossiers == 1
			#@prmtr[:cmds] << :getserial
			@prmtr[:getserial] = Hash.new
			@prmtr[:getserial][:submit] = "/doss"
			return erb :getserial
		else
			@prmtr[:choice] = Hash.new
			@prmtr[:choice][:submit] = "/doss"
			@prmtr[:choice][:title] = "Choisissez le dossier"
			@prmtr[:choice][:profils] = tableau_des_dossiers
			@prmtr[:choice][:back] = "/fin2"
			#@prmtr[:cmds] << :choice
			return erb :choice
		end
		#return erb :multicommand 
		
   
	when "doss"
		#puts "=== étape 3 === doss ==="
		num_ser = cookies["serial"]
		#puts "serial :"
		#puts num_ser
		#puts "nombre dossiers : "
		nombre_dossiers = cookies["number"]
		#puts nombre_dossiers
		tableau_des_profils = serial_vers_profils(num_ser)
		tableau_des_dossiers = profils_vers_dossiers(tableau_des_profils)
		tableau_des_types = Array.new
		profils_selectionnes = Array.new 
		if nombre_dossiers == "1"
			dossier_choisi = tableau_des_dossiers[0]
		else 
			xmlstr2 = params[:xml].to_s
			dossier_choisi = get_user_input_from(xmlstr2)
		end
		#puts dossier_choisi
		#response.set_cookie("dossier", { :value => dossier_choisi, :expires => (Time.now + 3600), :path => '/' })
		cookies["dossier"] = dossier_choisi
		for profil in tableau_des_profils
			raccourci = profil.AffichageRaccourci.content
			space_index = raccourci.index(' ') + 1
			dossier = raccourci[space_index..]
			if dossier == dossier_choisi
				type = raccourci[0...space_index - 1]
				tableau_des_types << type unless tableau_des_types.include? type
				profils_selectionnes << profil 
			end 
		end
		@prmtr[:choice] = Hash.new
		@prmtr[:choice][:submit] = "/prepare"
		@prmtr[:choice][:back] = "/init"
		@prmtr[:choice][:title] = "Choisissez le type"
		@prmtr[:choice][:profils] = tableau_des_types
		#@prmtr[:cmds] << :choice
		#return erb :multicommand
		return erb :choice
	
	when "prepare"
		#puts "=== étape 4 === prepare ==="
		xmlstr3 = params[:xml].to_s
		type_choisi = get_user_input_from(xmlstr3)
		dossier_choisi = cookies["dossier"]
		#puts "dossier choisi :"
		#puts dossier_choisi
		raccourci_choisi = type_choisi + " " + dossier_choisi
		num_ser = cookies["serial"]
		#puts "serial : "
		#puts num_ser
		#puts "nombre dossiers :"
		nombre_dossiers = cookies["number"]
		#puts nombre_dossiers
		tableau_des_profils = serial_vers_profils(num_ser)
		tableau_des_dossiers = profils_vers_dossiers(tableau_des_profils)
		tableau_des_types = Array.new
		profils_selectionnes = Array.new
		for profil in tableau_des_profils
			raccourci = profil.AffichageRaccourci.content
			space_index = raccourci.index(' ') + 1
			dossier = raccourci[space_index..]
			if dossier == dossier_choisi
				type = raccourci[0...space_index - 1]
				tableau_des_types << type unless tableau_des_types.include? type
				profils_selectionnes << profil 
			end 
		end
		for profil in profils_selectionnes
			raccourci = profil.AffichageRaccourci.content
			if raccourci_choisi == raccourci
				profil_choisi = profil
				break
			end
		end
		type_profil = get_entry_from(profil_choisi, "//TypeProfil")
		couleurs = get_entry_from(profil_choisi, "//Couleurs")
		case couleurs
		when "GRIS"
			colormode = "Gray"
		when "N_ET_B"
			colormode = "Mono"
		when "COULEURS"
			colormode = "Color"
		end
		resolution = get_entry_from(profil_choisi, "//Resolution")[1..]
		multipage = get_entry_from(profil_choisi, "//Multipage")
		case multipage
		when "True"
			singlepagefile = "false"
		when "False"
			singlepagefile = "true"
		end
		recto_verso = get_entry_from(profil_choisi, "//RectoVerso")
		case recto_verso
		when "BORD_LONG"
			shortedgebinding = "false"
			duplexscanenable = "true"
		when "NON"
			shortedgebinding = "false"
			duplexscanenable = "false"
		when "BORD_COURT"
			shortedgebinding = "true"
			duplexscanenable = "true"
		end
		separer_feuilles = get_entry_from(profil_choisi, "//SeparerFeuilles")
		case get_entry_from(profil_choisi, "//Redressement")
		when "AUTO"
			autodeskew = "true"
		when "NON"
			autodeskew = "false"
		end
		@prmtr[:scanglobal] = {
			:duplexscanenable => duplexscanenable,
			:colormode => colormode,
			:resolution => resolution,
			:filetype => get_entry_from(profil_choisi, "//TypeFichier"),
			:singlepagefile => singlepagefile,
			:autodeskew => autodeskew,
			:skipblankpage => get_entry_from(profil_choisi, "//SauterPagesVierges").downcase,
			:skipblankpagesensitivity => "0",
			:shortedgebinding => shortedgebinding,
			:submit => "/fin"
		}
		
		case type_profil
		when "FTP"
			#@prmtr[:cmds] << :cmd_form_message
			#@prmtr[:cmds] << :cmd_scansendftp
			#@prmtr[:form_msg] = {
			#	:objtitle    => 'Scan et envoi vers FTP',
			#	:msgbody     => 'Numérisation en cours...'
			#}
			@prmtr[:scanftp] = {
				:filename => type_choisi + "_" + dossier_choisi,
				:host_or_email => get_entry_from(profil_choisi, "//AdresseHoteEmail"),
				:user => get_entry_from(profil_choisi, "//NomUtilisateur"),
				:password => get_entry_from(profil_choisi, "//MotDePasse"),
				:storedir => get_entry_from(profil_choisi, "//Chemin") + "/", # doit finir par /
				:passivemode => get_entry_from(profil_choisi, "//FtpPassif").downcase,
				:portnum => get_entry_from(profil_choisi, "//PortFtp"),
			}
			return erb :cmd_scansendftp
		
		when "EMAIL"
			#@prmtr[:cmds] << :cmd_form_message
			#@prmtr[:cmds] << :cmd_scansendemail
			#@prmtr[:form_msg] = {
			#	:objtitle    => 'Scan et envoi vers EMAIL',
			#	:msgbody     => 'Numérisation en cours...',
			#	:back        => '/init',
			#}
			@prmtr[:scanemail] = {
				:email => get_entry_from(profil_choisi, "//AdresseHoteEmail"),
				:subject => "Document numérisé par DematFlux",
				:msgbody => "Veuillez trouver le document en pièce jointe.",
				:filename => type_choisi + "_" + dossier_choisi,
			}
			return erb :cmd_scansendemail
			
		when "RESEAU"
			#@prmtr[:cmds] << :cmd_form_message
			#@prmtr[:cmds] << :cmd_scansendreseau
			#@prmtr[:form_msg] = {
			#	:objtitle    => 'Scanner et envoyer vers RESEAU',
			#	:msgbody     => 'Numérisation en cours...',
			#	:back        => '/init',
			#}
			@prmtr[:scanreseau] = {
				:filename => type_choisi + "_" + dossier_choisi,
				:host_or_email => get_entry_from(profil_choisi, "//AdresseHoteEmail"),
				:user => get_entry_from(profil_choisi, "//NomUtilisateur"),
				:password => get_entry_from(profil_choisi, "//MotDePasse"),
				:storedir => get_entry_from(profil_choisi, "//Chemin"), #  ne doit pas finir par /
			}
			return erb :cmd_scansendreseau
			
		else 
			#@prmtr[:cmds] << :cmd_form_message
			@prmtr[:form_msg] = {
				:objtitle    => 'ERREUR',
				:msgbody     => "Ce mode n'est actuellement pas pris en charge.",
				:back        => '/init',
			}
			return erb :cmd_form_message
	
		end
        #return erb :multicommand
     
	when "fin"
		#puts "étape 5 === fin ==="
		# prévoir lecture des xml de fin pour accusé de réception
		reponse = params[:xml]
		erreur = get_entry_from(reponse, "//ErrorInfo")
		if erreur == "1"
			@prmtr[:yesno] = {
				:objtitle    => "",
				:msgbody     => "Opération terminée.",
				:yeslink     => "/init",
				:nolink      => "/fin3",
				:yeslabel    => "Nouvel envoi",
				:nolabel     => "Quitter"
			}
		else 
			@prmtr[:yesno] = {
				:objtitle    => "",
				:msgbody     => "Erreur dans le traitement ou l'envoi.",
				:yeslink     => "/init",
				:nolink      => "/fin3",
				:yeslabel    => "Nouvel envoi",
				:nolabel     => "Quitter"
			}
		end
		
		#@prmtr[:cmds] << :cmd_form_message
		#@prmtr[:form_msg] = {
		#	:pagetitle   => "OK",
		#	:objtitle    => "Opération terminée",
		#	:msgbody     => "Retour à l'écran principal."
		#}
		#return erb :multicommand
		return erb :yesno
		
	when "fin2"
		#puts "étape 6 === fin2 ==="
		#@prmtr[:cmds] << :cmd_form_message
		@prmtr[:info_msg] = {
			:objtitle    => "Opération abandonnée",
			:msgbody     => 'Retour au menu initial.',
		}
		#return erb :multicommand
		return erb :cmd_info_message
    
	when "fin3"
		@prmtr[:info_msg] = {
				:objtitle    => "Opération terminée",
				:msgbody     => 'Retour au menu initial.'
			}
		return erb :cmd_info_message
	
    else
        #@prmtr[:cmds] << :cmd_form_message
        @prmtr[:form_msg] = {
            :pagetitle   => "404 NOT FOUND", 
            :submit      => "./init",
            :back        => "./init",
            :objtitle    => "404",
            :description => "PAGE NOT FOUND",
            :msgbody     => "The page '#{endpoint}' you requested does not exist."
        }
        #return erb :multicommand
		return erb :cmd_form_message
    end
end


def get_model_serial_from(xml)
    kvarray = Array.new
    doc = REXML::Document.new(xml)
    begin
        doc.elements.each('SerioEvent/DbReadDone/ReadResults/ReadResult') { |kv|
            kvarray << {
                :key   => kv.elements['Key'].text,
                :value => kv.elements['Value'].text
            }
        }
    rescue
        #puts "PARSE ERROR OCCURRED."
    end
    return nil unless kvarray
    ret = nil
    kvarray.each { |kv|
        if kv[:key] == "1.3.6.1.2.1.25.3.2.1.3.1"
            ret = Hash.new unless ret
			ret[:model] = kv[:value]
        elsif kv[:key] == "1.3.6.1.2.1.43.5.1.1.17.1"
            ret = Hash.new unless ret
            ret[:serial] = kv[:value]
        end
    }
    ret
end


def get_user_input_from(xml)
    kvarray = Array.new
    doc = REXML::Document.new(xml)
    begin
        doc.elements.each('SerioEvent/UserInput/UserInputValues/KeyValueData') { |kv|
            kvarray << {
                :key   => kv.elements['Key'].text,
                :value => kv.elements['Value'].text
            }
        }
    rescue
        #puts "PARSE ERROR OCCURRED."
    end
    return nil unless kvarray
    ret = kvarray[0][:value]
    ret
end

def get_entry_from(xml_profil, key)
	# key est de la forme "//NumOnglet" ou //UneEntréeDuXml
    doc_profil = REXML::Document.new(xml_profil.to_s)
	ligne =  XPath.first(doc_profil, key)
	#puts key unless ligne
	return "erreur" + key unless ligne
    return ligne.text  
end


#-------------------------------------------------
# Routes
#-------------------------------------------------


get "/:endpoint" do
  content_type :xml
  build_iojob(params[:endpoint])
end

post "/:endpoint" do
  content_type :xml
  build_iojob(params[:endpoint])
end



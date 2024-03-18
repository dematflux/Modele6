# 11.modeleur 0.4

require 'rubygems'
require 'sinatra'

require 'rexml/document'
require 'nokogiri'

include REXML

#-------------------------------------------------
# Methods
#-------------------------------------------------


def build_iojob(endpoint, phase=nil)
    @prmtr = Hash.new
    @prmtr[:cmds] = []           # erb templates to put in SerioCommands.
    case endpoint
    when "init"
		# definir erb
		@prmtr[:submit] = "/readcnf"
		# definir multicmd
		@prmtr[:cmds] << :getserial
        return erb :multicommand
   
    when "readcnf"
		xmlstr = params[:xml].to_s
		model_serial = get_model_serial_from(xmlstr)
		serial_cnf = "./cnf/" + model_serial[:serial] + ".cnf3"
		doc_cnf = Nokogiri::Slop(File.read(serial_cnf)) 
		$tableau_des_profils = doc_cnf.DonnesDeConfiguration3.DonneesDeChampsProfil.DonneesDeChampProfil
		tableau_des_dossiers = Array.new
		for profil in $tableau_des_profils
			raccourci = profil.AffichageRaccourci.content
			space_index = raccourci.index(' ') + 1
			dossier = raccourci[space_index..]
			tableau_des_dossiers << dossier unless tableau_des_dossiers.include? dossier
		end
		# definir erb
		@prmtr[:submit] = "/doss"
		@prmtr[:title] = "Choisissez le dossier"
		@prmtr[:profils] = tableau_des_dossiers
		@prmtr[:back] = "/fin2"
		# definir multicmd
		@prmtr[:cmds] << :choice
        return erb :multicommand
   
	when "doss"
		xmlstr2 = params[:xml].to_s
		$dossier_choisi = get_user_input_from(xmlstr2)
		tableau_des_types = Array.new
		$profils_selectionnes = Array.new 
		for profil in $tableau_des_profils
			raccourci = profil.AffichageRaccourci.content
			space_index = raccourci.index(' ') + 1
			dossier = raccourci[space_index..]
			if dossier == $dossier_choisi
				type = raccourci[0...space_index - 1]
				tableau_des_types << type unless tableau_des_types.include? type
				$profils_selectionnes << profil 
			end 
		end
		# definir erb
		@prmtr[:submit] = "/prepare"
		@prmtr[:title] = "Choisissez le type"
		@prmtr[:profils] = tableau_des_types
		@prmtr[:back] = "/init"
		# definir multicmd
		@prmtr[:cmds] << :choice
        return erb :multicommand
	
	when "prepare"
		xmlstr3 = params[:xml].to_s
		type_choisi = get_user_input_from(xmlstr3)
		raccourci_choisi = type_choisi + " " + $dossier_choisi
		for profil in $profils_selectionnes
			raccourci = profil.AffichageRaccourci.content
			if raccourci_choisi == raccourci
				profil_choisi = profil
				break
			end
		end
		type_profil = get_entry_from(profil_choisi, "//TypeProfil")
		# nom_de_fichier = get_entry_from(profil_choisi, "//NomDeFichier") $ non utilisé car réécrit
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
		# taille_document = get_entry_from(profil_choisi, "//TailleDocument")
		# TailleDocument / DocSize est toujours AUTO 
		# taille_fichier = get_entry_from(profil_choisi, "//TailleFichier")
		# TailleFichier / 
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
			:SkipBlankPageSensitivity => "Normal",
			:shortedgebinding => shortedgebinding,
		}
		
		case type_profil
		when "FTP"
			# definir multicmd
			@prmtr[:cmds] << :cmd_form_message
			@prmtr[:cmds] << :cmd_scansendftp
			# @prmtr[:cmds] << :cmd_scansend
			@prmtr[:form_msg] = {
				:objtitle    => 'Scan et envoi vers FTP',
				:msgbody     => 'Numérisation en cours...',
				:back        => '/init',
			}
			@prmtr[:scanftp] = {
				:filename => type_choisi + "_" + $dossier_choisi,
				:host_or_email => get_entry_from(profil_choisi, "//AdresseHoteEmail"),
				:user => get_entry_from(profil_choisi, "//NomUtilisateur"),
				:password => get_entry_from(profil_choisi, "//MotDePasse"),
				:storedir => get_entry_from(profil_choisi, "//Chemin") + "/", # doit finir par /
				:passivemode => get_entry_from(profil_choisi, "//FtpPassif").downcase,
				:portnum => get_entry_from(profil_choisi, "//PortFtp"),
			}
		
		when "EMAIL"
			@prmtr[:cmds] << :cmd_form_message
			@prmtr[:cmds] << :cmd_scansendemail
			@prmtr[:form_msg] = {
				:objtitle    => 'Scan et envoi vers EMAIL',
				:msgbody     => 'Numérisation en cours...',
				:back        => '/init',
			}
			@prmtr[:scanemail] = {
				:email => get_entry_from(profil_choisi, "//AdresseHoteEmail"),
				:subject => "Document numérisé par DematFlux",
				:msgbody => "Veuillez trouver le document en pièce jointe.",
				:filename => type_choisi + "_" + $dossier_choisi,
			}
			
		when "RESEAU"
			@prmtr[:cmds] << :cmd_form_message
			@prmtr[:cmds] << :cmd_scansendreseau
			@prmtr[:form_msg] = {
				:objtitle    => 'Scanner et envoyer vers RESEAU',
				:msgbody     => 'Numérisation en cours...',
				:back        => '/init',
			}
			@prmtr[:scanreseau] = {
				:filename => type_choisi + "_" + $dossier_choisi,
				:host_or_email => get_entry_from(profil_choisi, "//AdresseHoteEmail"),
				:user => get_entry_from(profil_choisi, "//NomUtilisateur"),
				:password => get_entry_from(profil_choisi, "//MotDePasse"),
				:storedir => get_entry_from(profil_choisi, "//Chemin"), #  ne doit pas finir par /
			}
			
		else 
			@prmtr[:cmds] << :cmd_form_message
			@prmtr[:form_msg] = {
				:objtitle    => 'ERREUR',
				:msgbody     => "Ce mode n'est actuellement pas pris en charge.",
				:back        => '/init',
			}
	
		end
		
        return erb :multicommand
     
	when "fin"
		@prmtr[:cmds] << :cmd_form_message
		@prmtr[:form_msg] = {
			:objtitle    => 'Opération terminée',
			:msgbody     => 'DematFlux a numérisé votre document.',
		}
		return erb :multicommand
		
	when "fin2"
		@prmtr[:cmds] << :cmd_form_message
		@prmtr[:form_msg] = {
			:objtitle    => 'Opération abandonnée',
			:msgbody     => 'Retour au menu initial. Appuyez sur le bouton Ok',
		}
		return erb :multicommand
     
    else
        @prmtr[:cmds] << :cmd_form_message
        @prmtr[:form_msg] = {
            :pagetitle   => "404 NOT FOUND", 
            :submit      => "./init",
            :back        => "./init",
            :objtitle    => "404",
            :description => "PAGE NOT FOUND",
            :msgbody     => "The page '#{endpoint}' you requested does not exist."
        }
        return erb :multicommand
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
        puts "PARSE ERROR OCCURRED."
    end
    # 
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
        puts "PARSE ERROR OCCURRED."
    end
    # 
    return nil unless kvarray
    ret = kvarray[0][:value]
    ret
end

def get_entry_from(xml_profil, key)
	# key est de la forme "//NumOnglet"
    doc_profil = REXML::Document.new(xml_profil.to_s)
	# doc_profil.elements.each do |entry| 
	# 	entry.elements.each do |x|
	#		puts x
	#	end
	ligne =  XPath.first(doc_profil, key)
	puts key unless ligne
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



###############################################################################################
#
#	Name		:
#		DictionaryAPI.tcl
#
#	Description	:
#		TCL script for eggdrop that uses Dictionary v2 API to find
#		and get word definitions
#
#		Script TCL pour eggdrop qui utilise l'API Dictionary v2 pour rechercher et
#		obtenir des définitions de mots
#
#	Donation	:
#		https://github.com/MalaGaM/DONATE
#
#	Auteur		:
#		MalaGaM @ https://github.com/MalaGaM
#
#	Website		:
#		https://github.com/MalaGaM/TCL-DictionaryAPI
#
#	Support		:
#		https://github.com/MalaGaM/TCL-DictionaryAPI/issues
#
#	Docs		:
#		https://github.com/MalaGaM/TCL-DictionaryAPI/wiki
#
#	Thanks to	:
#		CrazyCat	-	Community french and help of eggdrop	:	https://www.eggdrop.fr
#		MenzAgitat	-	Tips/Toolbox							:	https://www.boulets.oqp.me/
#		mabrook		-	Reports bugs and test					:	https://forum.eggdrop.fr/member.php?action=profile&uid=3935
#
###############################################################################################
if { [::tcl::info::commands ::DictionaryAPI::unload] eq "::DictionaryAPI::unload" } { ::DictionaryAPI::unload }
if { [package vcompare [regexp -inline {^[[:digit:]\.]+} $::version] 1.6.20] == -1 } { putloglev o * "\[DictionaryAPI - erreur\] La version de votre Eggdrop est ${::version}; DictionaryAPI ne fonctionnera correctement que sur les Eggdrops version 1.6.20 ou supérieure." ; return }
if { [::tcl::info::tclversion] < 8.5 } { putloglev o * "\[DictionaryAPI - erreur\] DictionaryAPI nécessite que Tcl 8.5 (ou plus) soit installé pour fonctionner. Votre version actuelle de Tcl est ${::tcl_version}. $ERROR" ; return }
if { [catch { package require tls 1.7} ERROR] } { putloglev o * "\[DictionaryAPI - erreur\] DictionaryAPI nécessite le package tls 1.7 (ou plus) pour fonctionner. Le chargement du script a été annulé. $ERROR" ; return }
if { [catch { package require http 2.9} ERROR] } { putloglev o * "\[DictionaryAPI - erreur\] DictionaryAPI nécessite le package http 2.9 (ou plus) pour fonctionner. Le chargement du script a été annulé. $ERROR" ; return }
if { [catch { package require json 1.3} ERROR] } { putloglev o * "\[DictionaryAPI - erreur\] DictionaryAPI nécessite le package json 1.3 (ou plus) pour fonctionner. Le chargement du script a été annulé. $ERROR" ; return }
namespace eval ::DictionaryAPI {
	###############################################################################
	### Configuration
	###############################################################################
	
	# List of salons where the script will be active put "*" for all channels
	# Example to allow #channel1 and #channel2
	# define the channels(Allow) "#channel1 #channel2"
	#
	# Liste des salons où le script sera active mettre "*" pour tout les salons
	# Exemple pour autoriser #channel1 et #channel2
	#	set Channels(Allow)				" #channel1  #channel2"
	set Channels(Allow)				"*"

	### Public IRC commands | Commandes IRC publique
	# Define the IRC commands that the script should respond to and look for definitions.
	# Définissez les commandes IRC auquel le script doit répondre et chercher les definitions.
	variable public_cmd				".define !DictionaryAPI .definition"

	# Autorisations pour la commande publique
	variable public_cmd_auth		"-"

	### Current language for output | Langue courante pour la sortie
	# List: en,hi,es,fr,ja,ru,de,it,ko,pt-br,ar,tr
	variable Lang_current			"en"

	# Annonce prefix-> devant les annonce irc
	variable Annonce_Prefix			"\00301,00DictionaryAPI\003> "

	### Formatting of text by block type. | Formatage du texte par bloc de type.
	# Creation of the style, colors by type of block for the creation of the output display.
	# Creation du style, couleurs par type de bloc pour la creation de l'affichage de sortie.
	##
	# "\${DICT_DEFINITION}"			: The definition text | Le texte de définition
	# "\${DICT_NUMBER}"				: The numbering of the definition | La numerotation de la définition 
	# "\${DICT_WORD}"				: The word corresponding to the definition | Le mot correspondant à la définition
	# "\${DICT_TYPE}"				: The part of the speech | La partie du discours
	# "\${DICT_EXAMPLE}"			: Example of use of the word | Exemple d'utilisation du mot
	# "\${DICT_SYNONYMS}"			: Synonyms of the word | Les synonymes du mot
	# "\${DICT_ANTONYMS}"			: The antonyms of the word | Les antonymes du mot
	# "\${DICT_PHONETICS}"			: The phonetics of the word | Les phonétique du mot
	# "\n"							: Retour a la ligne, nouvelle phrase??
	###	
	variable BLOCK_DEFINITION		" > \${DICT_DEFINITION}"
	variable BLOCK_NUMBER			" \${DICT_NUMBER} "
	variable BLOCK_WORD				"\002\00301,00\"\${DICT_WORD}\"\003\002"
	variable BLOCK_TYPE				" - \${DICT_TYPE}"
	variable BLOCK_EXAMPLE			" > \00302\"\${DICT_EXAMPLE}\"\003"
	variable BLOCK_SYNONYMS			" > (\${DICT_SYNONYMS})"
	variable BLOCK_ANTONYMS			" != \${DICT_ANTONYMS}"
	variable BLOCK_PHONETICS_TEXT	" (\${DICT_PHONETICS_TEXT})"
	variable BLOCK_PHONETICS_AUDIO	"\n PHONETICS AUDIO: \${DICT_PHONETICS_AUDIO}"
	### Creation of the image output by positioning block types | Creation de la sortie l'image en positionnement des types de bloc
	# Block type available, if it exists for the word ;
	# Type de bloc disponible, si elle existe pour le mot :
	##
	# "\${BLOCK_DEFINITION}"
	# "\${BLOCK_NUMBER}"
	# "\${BLOCK_WORD}"
	# "\${BLOCK_TYPE}"
	# "\${BLOCK_EXAMPLE}"
	# "\${BLOCK_SYNONYMS}"
	# "\${BLOCK_ANTONYMS}"
	# "\${BLOCK_PHONETICS_TEXT}"
	# "\${BLOCK_PHONETICS_AUDIO}"
	# "\n"							: Retour a la ligne, nouvelle phrase
	###
	# Position them in the variable below in the desired order
	# Positionner-les dans la variable ci-dessous dans l'ordre souhaité

	# Multi exemple:
	#
	variable Annonce_Show			"\${DICT_WORD}\${DICT_PHONETICS_TEXT}\${DICT_TYPE}\${DICT_SYNONYMS}\${DICT_ANTONYMS}\${DICT_NUMBER}\${DICT_DEFINITION}\${DICT_EXAMPLE}\${DICT_PHONETICS_AUDIO}"
	#variable Annonce_Show			"\${DICT_WORD}\${DICT_PHONETICS}\${DICT_SYNONYMS}\${DICT_ANTONYMS}\${DICT_NUMBER}\${DICT_DEFINITION}\${DICT_EXAMPLE}"
	#variable Annonce_Show			"\${DICT_NUMBER}\${DICT_WORD}\${DICT_TYPE}\n\${DICT_DEFINITION}\n\${DICT_EXAMPLE}"

	### Block type in case of result not found | Type de bloc en cas de résultat non trouver
	# "\${WORD_SEARCH}"			: word not found
	# "\${URL_Link}"			: url not found
	###
	# Position them in the variable below in the desired order
	# Positionner-les dans la variable ci-dessous dans l'ordre souhaité
	variable Annonce_notfound		"Aucune définition trouvée pour \00306\${WORD_SEARCH}\002\003."
	#variable Annonce_notfound		"No definition found for \00306\${WORD_SEARCH}\002\003. (\${URL_Link})"

	# Maximum number of results | Nombre de resultats maximun
	variable max_annonce_default	10

	# Maximum number of results defined by the user | Nombre de résultats maximum défini par l'utilisateur
	variable max_annonce_user		10

	# After how many seconds do we decide that the website used by the script to display
	# the definitions is offline (or too ready) without a response from it?
	#
	# Après combien de secondes décide-t-on que le site web utilisé par le script
	# pour afficher les définitions est offline (ou trop lent) en l'absence de
	# réponse de sa part ?
	variable HTTP_TIMEOUT			10

	# USE HTTPS (1) OR HTTP (0)
	variable USE_HTTP_SSL			1

	# URL (n'y touchez pas à moins d'avoir une bonne raison de le faire)
	variable HTTP_URL_API			"api.dictionaryapi.dev/api/v2/entries"

	# User agent for http
	variable HTTP_USERAGENT			"Mozilla/5.0 (Windows; U; Windows NT 6.1; en-GB; rv:1.9.2.2) Gecko/20100316 Firefox/3.6.2"
	variable HTTP_ERROR				"Error of GetURL, see partyline for more details."
	###############################################################################
	### Fin de la configuration
	###############################################################################


	#############################################################################
	### Initialisation
	#############################################################################
	array set script				[list \
										"name"		"DictionaryAPI"	\
										"auteur"	"MalaGaM @ https://github.com/MalaGaM" \
										"version"	"1.2.3"
									]
	if { $USE_HTTP_SSL == 1 } {
		variable HTTP_URL_API		"https://${HTTP_URL_API}"
	} else {
		variable HTTP_URL_API		"http://${HTTP_URL_API}"
	}
	proc unload { args } {
		putlog "Désallocation des ressources de ${::DictionaryAPI::script(name)}..."
		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		foreach running_utimer [utimers] {
			if { [::tcl::string::match "*[namespace current]::*" [lindex $running_utimer 1]] } { killutimer [lindex $running_utimer 2] }
		}
		namespace delete ::DictionaryAPI
	}
}
proc ::DictionaryAPI::GetURL { URL_Link } {
	if { $::DictionaryAPI::USE_HTTP_SSL == 1 } { ::http::register https 443 [list ::tls::socket -autoservername true] }
	# on modifie l'urlencoding car dicoreverso.net ne comprend que l'utf-8 dans ses URLs.
	array set httpconfig [::http::config]
	::http::config -urlencoding utf-8 -useragent $::DictionaryAPI::HTTP_USERAGENT
	# on restaure l'urlencoding comme il était avant qu'on y touche
	::http::config -urlencoding $httpconfig(-urlencoding)
	if { [catch { set URL_TOKEN [::http::geturl $URL_Link -timeout [expr $::DictionaryAPI::HTTP_TIMEOUT * 1000]] } ERR] } {
		putlog "::DictionaryAPI::GetURL La connexion à [set URL_Link] n'a pas pu être établie. Il est possible que le site rencontre un problème technique."
		putlog "::DictionaryAPI::ERROR $ERR"
		if { $::DictionaryAPI::USE_HTTP_SSL == 1 } { ::http::unregister https }
		return 0
	}

	# on extrait la partie qui nous intéresse et sur laquelle on va travailler
	set URL_DATA		[::http::data $URL_TOKEN]
	set URL_DATA		[encoding convertfrom utf-8 $URL_DATA]
	::http::cleanup $URL_TOKEN
	if { $::DictionaryAPI::USE_HTTP_SSL == 1 } { ::http::unregister https }
	return $URL_DATA;

}

###############################################################################
### Procédure principale
###############################################################################
proc ::DictionaryAPI::SetBlock { WHAT VALUE } {
	set DICT_$WHAT $VALUE
	set ::DictionaryAPI::DICT_$WHAT [subst [subst $[join ::DictionaryAPI::BLOCK_$WHAT]]]
}
proc ::DictionaryAPI::Search { nick host hand chan arg } {
	if { $::DictionaryAPI::Channels(Allow) != "*" && [lsearch -nocase $::DictionaryAPI::Channels(Allow) $chan] == "-1" } { 
		set MSG    "DictionaryAPI: The channel '$chan' is not in allow channel."
		putlog $MSG
		putserv "PRIVMSG $chan :$MSG"
		return
	}
	set WORD_SEARCH			[stripcodes bcruag $arg]
	if { $WORD_SEARCH == "" } {
		putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix}HELP    : [join $::DictionaryAPI::public_cmd "|"] <word> "
		putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix}LANG    : \[-lang=<en,hi,es,fr,ja,ru,de,it,ko,pt-br,ar,tr>\] | Current lang: $::DictionaryAPI::Lang_current "
		putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix}LIMIT   : \[-limit=<1-$::DictionaryAPI::max_annonce_user>\] | default limit: $::DictionaryAPI::max_annonce_default "
		putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix}EXAMPLE : [lindex $::DictionaryAPI::public_cmd 0] Diccionario -lang=es -limit=6"
		putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix}HELP    : [join $::DictionaryAPI::public_cmd "|"] SetLang <en,hi,es,fr,ja,ru,de,it,ko,pt-br,ar,tr> | Set Current language"
		putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix}EXAMPLE : [lindex $::DictionaryAPI::public_cmd 0] SetLang es"
		return
	}
	if { [string match -nocase [lindex $arg 0] "SetLang"] } {
		if { [lindex $arg 1] != "" } {
			set ::DictionaryAPI::Lang_current [lindex $arg 1]
			putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix} Current lang is now : $::DictionaryAPI::Lang_current"
		} else {
			putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix} Current lang is : $::DictionaryAPI::Lang_current"
		}

		return
	}
	set RE {-limit[\s|=](\S+)}
	if { [regexp -nocase -- $RE $WORD_SEARCH -> limit] } {
		regsub -nocase -- $RE $WORD_SEARCH {} WORD_SEARCH
		set WORD_SEARCH		[string trim $WORD_SEARCH]
		if { $limit > $::DictionaryAPI::max_annonce_user } {
			putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix} limit max is $::DictionaryAPI::max_annonce_user"
			set limit		$::DictionaryAPI::max_annonce_user
		}
	} else {
		set limit	$::DictionaryAPI::max_annonce_default
	}
	set RE {-lang[\s|=](\S+)}
	if { [regexp -nocase -- $RE $WORD_SEARCH -> lang] } {
		regsub -nocase -- $RE $WORD_SEARCH {} WORD_SEARCH
		set WORD_SEARCH		[string trim $WORD_SEARCH]
		set URL_Link		"${::DictionaryAPI::HTTP_URL_API}/${lang}/${WORD_SEARCH}"
	} else {
		set URL_Link		"${::DictionaryAPI::HTTP_URL_API}/${::DictionaryAPI::Lang_current}/${WORD_SEARCH}"
	}

	set URL_DATA		[::DictionaryAPI::GetURL $URL_Link]
	if { $URL_DATA == 0 } { 
		putserv "PRIVMSG $chan :$::DictionaryAPI::script(name) > $::DictionaryAPI::HTTP_ERROR"
		return 0
	}

	foreach { PARENT } [::json::json2dict $URL_DATA] {
		if { $PARENT == "title" } {
			putserv "PRIVMSG $chan :[subst $::DictionaryAPI::Annonce_notfound]"
			return
		}
		# init/reset vars
		variable DICT_DEFINITION			""
		variable DICT_WORD					""
		variable DICT_TYPE					""
		variable DICT_NUMBER				0
		variable DICT_EXAMPLE				""
		variable DICT_SYNONYMS				""
		variable DICT_ANTONYMS				""
		variable DICT_PHONETICS_AUDIO		""
		variable DICT_PHONETICS_TEXT		""
		set SUBCAT							[dict get $PARENT]
		set TMP_phonetics					[dict get $SUBCAT phonetics]
		::DictionaryAPI::SetBlock WORD		[dict get $SUBCAT word]
		if { $TMP_phonetics != "{}" } {
			::DictionaryAPI::SetBlock PHONETICS_TEXT	$TMP_phonetics
			if { [dict exists [join $TMP_phonetics] audio] } {
				::DictionaryAPI::SetBlock PHONETICS_AUDIO	[string map {"//" "https://"} [dict get [join $TMP_phonetics] audio]]
			}
			if { [dict exists [join $TMP_phonetics] text] } {
				::DictionaryAPI::SetBlock PHONETICS_TEXT	[dict get [join $TMP_phonetics] text]
			}
			
			
			unset TMP_phonetics
		}
		set SUBMEANINGS						[dict get $SUBCAT meanings]
		foreach { ENFANT } [dict get $SUBCAT meanings] {
			set TMP_partOfSpeech			[dict get $ENFANT partOfSpeech]
			if { $TMP_partOfSpeech != "{}" } {
				::DictionaryAPI::SetBlock TYPE	$TMP_partOfSpeech
				unset TMP_partOfSpeech
			}
			foreach { SUBDEFINITION } [dict get $ENFANT definitions] {
				::DictionaryAPI::SetBlock DEFINITION		[dict get $SUBDEFINITION definition]
				if {
					[dict exists $SUBDEFINITION synonyms] \
					&& [dict get $SUBDEFINITION synonyms] != ""
				} {
					::DictionaryAPI::SetBlock SYNONYMS		[join [dict get $SUBDEFINITION synonyms] ", "]
				}
				if { [dict exists $SUBDEFINITION example] } {
					::DictionaryAPI::SetBlock EXAMPLE		[dict get $SUBDEFINITION example]
				}
				::DictionaryAPI::SetBlock NUMBER			[expr $DICT_NUMBER+1]
				foreach Annonce [split [subst ${::DictionaryAPI::Annonce_Show}] "\n"] {
					putserv "PRIVMSG $chan :${::DictionaryAPI::Annonce_Prefix}$Annonce"
				}
				if { $limit == $DICT_NUMBER } { return }
			}
		}
	}
}
###############################################################################
### Binds
###############################################################################
foreach b $::DictionaryAPI::public_cmd {
	bind pub $::DictionaryAPI::public_cmd_auth $b ::DictionaryAPI::Search
}
bind evnt - prerehash ::DictionaryAPI::unload


putlog "$::DictionaryAPI::script(name) v$::DictionaryAPI::script(version) by $::DictionaryAPI::script(auteur) loaded."
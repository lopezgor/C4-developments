#====================================================================================================================================================
#
#        FILE: deploy.sh
#
#       USAGE: ./deploy.sh [PARAMETERS]
#
#  PARAMETERS: + PO_CODE · Projects Office Code
#	       + APP_CODE · APPlication Code
#	       + TAG · NOT IN USE!!! 
#	       + APPSERV_TYPE · Application Server Type (JBOSS or WAS)
#	       + DEPLOY_CONFIG · TRUE or FALSE Configuration Deployment
#	       + BATCH_DIR · BATCH Environment Directory (e.g.: apliccoper, aplicref)
#	       + ENV · ENVironment (correctivo, aceptacion, preproduccion, etc...)
#	       + BATCH_HOST · Self explanatory
#	       + JBOSS_HOST · Self explanatory
#	       + DEPLOY_METHOD · V1 (LEGACY) o V2 (CINTEGRATION)
#	       + ARTIFACT_REPO · Self explanatory (actually "bote de QA", in the future 'Artifactory')
#	       + VERSION · Depending on DEPLOY_METHOD:
#				+ V1 · VERSION includes the complete literal which identifies the file
#					(e.g. GLCGestOp_ES_20160713_V_3_16_8_0_RC0_B0)
#				+ V2 · VERSION includes only the literal from ARTIFACT_ID
#					(e.g. ES_20160713_V_3_16_8_0_RC0_B0 being ARTIFACT_ID = GLCGestOp)
#	       + ARTIFACT_ID · Artifact ID
#	       + GROUP_ID · V2 Repository Directory
#
#     PURPOSE: deployment script for batch and online (with or without configuration) artifacts 
#
# DESCRIPTION:+ the script is divided in two sections:
#		+ Section One: an initial section for retrieving the artifacts to be deployed considering two approachings (through 'DEPLOY_METHOD' parameter)
#			+ V1 (LEGACY): from 'deploy.sh' the 'get-qa-files.sh' script in the Batch and jboss host is invoked, for the downloading from the
#			  QA repository of all artifacts, carrying out the preparation for the subsequent deployment in the Section Two of the 'deploy.sh'
#			+ V2 (CINTEGRATION): desde 'deploy.sh' se recogen los ficheros del repositorio de Integración Continua
#			  para dejarlos en la misma ubicacion que con la V1
#		+ Section Two: carrying out of deployment and possible rollback case of error
#
#  PARAMETROS: 
#	        
#====================================================================================================================================================

clear;                                             

if [ $# -lt 12 ]; then    
    ## Elimination of TAG variable
    ## echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|12 Parameters are required for deploy a TAG : PO_CODE, APP_CODE, TAG, ENV, DEPLOY_CONFIG, ENV_DIR, ENV_BATCH, BATCH_HOST, JBOSS_HOST, DEPLOY_METHOD, ARTIFACT_ID, GROUP_ID"
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|12 Parameters are required for deploying a TAG : PO_CODE, APP_CODE, ENV, DEPLOY_CONFIG, ENV_DIR, ENV_BATCH, BATCH_HOST, JBOSS_HOST, DEPLOY_METHOD, ARTIFACT_ID, GROUP_ID"
    exit 1
fi

#---------------------------------
#
# SECTION ONE
#
#	Artifacts retrieving according DEPLOY_METHOD type
#
#---------------------------------

#---------------------------------
# Variable initialization
#---------------------------------
LEGACY_DEPLOY_MODE="V1"
CINTEGRATION_DEPLOY_MODE="V2"

#---------------------------------
# Recogida de los parametros del script
#---------------------------------
echo "###################################################"
echo " + COMIENZO DEPLOY"
echo " + PARAMETROS : "
echo " +    PO_CODE              = "$PO_CODE 
echo " +    COD_AP              = "$COD_AP
echo " +    TAG                 = "$TAG
echo " +    SERV                = "$SERV
echo " +    OPER                = "$BATCH_HOST
echo " +    JBOSS               = "$JBOSS_HOST
echo " +    DEPLOY_CONFIG                = "$DEPLOY_CONFIG
echo " +    BATCH_DIR         = "$BATCH_DIR
echo " +    ENV             = "$ENV
echo " +    BATCH_HOST          = "$BATCH_HOST
echo " +    JBOSS_HOST          = "$JBOSS_HOST
echo " +    DEPLOY_METHOD       = "$DEPLOY_METHOD
echo " +    ARTIFACT_REPO  = "$ARTIFACT_REPO
echo " +    VERSION             = "$VERSION
echo " +    ARTIFACT_ID          = "$ARTIFACT_ID
echo " +    GROUP_ID             = "$GROUP_ID
echo "###################################################"


#-- DEPLOY_METHOD checking
echo $LEGACY_DEPLOY_MODE" "$CINTEGRATION_DEPLOY_MODE | grep -q $DEPLOY_METHOD
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Deploy method values must be V1 or V2"
    exit 1      
fi     

#---------------------------------
# Artifacts Retrieving according to DEPLOY_METHOD
#---------------------------------

#-- Common to the two DEPLOY_METHOD variants

    #-- Find and replace all (//) ocurrence of '_ES' with 'InstalablesSH_Es' within the VERSION literal
    INSTALABLE_BATCH=${VERSION//_ES/InstalablesSH_ES}".zip"

    
#*
#if [ $DEPLOY_METHOD = $LEGACY_DEPLOY_MODE ]; then
#    -- rgordo comments: si instalable_batch lo inicializa igual que con la V2 por qué no lo sacas fuera?
#    INSTALABLE_BATCH=${VERSION//_ES/InstalablesSH_ES}".zip"
    
#elif [ $DEPLOY_METHOD = $CINTEGRATION_DEPLOY_MODE ]; then
    #copia los artefactos del bote de integracion continua al bote del generador de instalables
    #y verifica que
#    INSTALABLE_BATCH=${VERSION//_ES/InstalablesSH_ES}".zip"

    if [ $DEPLOY_METHOD = $CINTEGRATION_DEPLOY_MODE ]; then
	TAG=$ARTIFACT_ID_$VERSION
	CONFIG_APP=${TAG//_ES/Configuration_ES}".rar"
	EAR=$ARTIFACT_ID_$VERSION.ear

    #-- rgordo comments
    #	Comprueba que todos los artifacts existen
    checkArtifact $INSTALABLE_BATCH
    ret_instalable=$?
    
    checkArtifact $CONFIG_APP
    ret_config=$?
    
    checkArtifact $EAR
    ret_ear=$?
    
    if [ "$ret_instalable" -ne 0 ] || [ "$ret_config" -ne 0 ] || [ "$ret_ear" -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Failure to find artifacts."
	exit 1
    fi 
fi    

echo "fin"
exit 0

#---------------------------------
# Invocation of 'init-deploy.sh' on the BATCH_HOST in order to check the compliance
#
# -- invocation & parameters: init-deploy.sh $PO_CODE $INSTALABLE_BATCH $BATCH_DIR $APP_CODE $ENV
#---------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Init deploy $APP_CODE $TAG"
ssh -t iecontin@$BATCH_HOST "sudo -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/init-deploy.sh $PO_CODE $INSTALABLE_BATCH $BATCH_DIR $APP_CODE $ENV"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t init deploy, check enviroment!!!!"
    exit $retVal
fi
echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Init deploy $APP_CODE"   


echo `date "+%Y-%m-%d %H:%M:%S"`"|START-GLOBAL|Deployment TAG : "$TAG
echo ""


#---------------------------------
# EAR Downloading
#
# -- invocation & parameters: get-qa-files.sh $APP_CODE $TAG.ear
#---------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Downloading EAR file $TAG.ear"
ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/get-qa-files.sh $APP_CODE $TAG.ear" 2>&1 >/dev/null
ret=$?
if [ $ret -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t download $TAG.ear (Rollback no required)"
    #No hay rollback, no se ha instalado nada.
    exit $ret
else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|File downloaded $TAG.ear"
    echo ""
fi

#---------------------------------
# Configuration Online Downloading
#
# -- invocation & parameters: get-qa-files.sh $COD_AP $CONFIG_APP
#---------------------------------
if [ $DEPLOY_CONFIG == "SI" ]; then
    CONFIG_APP=${TAG//_ES/Configuration_ES}".rar"	
    echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Downloading EAR config. file $CONFIG_APP"
    ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/get-qa-files.sh $APP_CODE $CONFIG_APP" 2>&1 >/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t download $CONFIG_APP (Rollback no required)"
	#No hay rollback, no se ha instalado nada.
	exit $ret
    else
	echo `date "+%Y-%m-%d %H:%M:%S"`"|END|File downloaded $CONFIG_APP"
	echo ""
    fi
fi

#---------------------------------
# instalable_batch Downloading and deployment preparation
#
# -- invocation & parameters: get-qa-files.sh $COD_AP $CONFIG_APP
#---------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Downloading InstalableSH file $INSTALABLE_BATCH"
ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/get-qa-files.sh $PO_CODE $INSTALABLE_BATCH $BATCH_DIR $APP_CODE"
ret=$?
if [ $ret -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t download $INSTALABLE_BATCH (Rollback no required)"
    #No hay rollback, no se ha instalado nada.
    exit $ret
else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|File downloaded $INSTALABLE_BATCH"
    echo ""
fi

#---------------------------------
# INSTALABLE_BATCH Downloading and deployment preparation
#
# -- invocation & parameters: get-qa-files.sh $COD_AP $CONFIG_APP
#---------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Stoping server for app $APP_CODE"
stopServer "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems stoping server for app $APP_CODE"
    stopServer "ROLLBACK"
    retVal=$?
    if [ "$retVal" -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems starting server for app $APP_CODE"
	exit $retVal
    else
	echo `date "+%Y-%m-%d %H:%M:%S"`"|WARN|Started server for app $APP_CODE, the deployment has failed!!!"
	exit 1
    fi
else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Stoped server for app $APP_CODE"
    echo ""
fi

#########################################################
# BACKUP DE APLICACION ONLINE                           #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Begining the backup of $APP_CODE"
backup-ear "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems during the backup process of $APP_CODE"
    backup-ear "ROLLBACK"
    retVal=$?
    # Por aqui nunca entraria, en rollback de backup-ear siempre se hace un exit.
    #if [ "$retVal" -ne 0 ]; then
    #   echo "    >> ERROR ($retVal) BACKUP APP : $APP_CODE"
    #   exit $retVal
    #else
    #   echo " >> FINAL ROLLBACK APP : $APP_CODE"
    #   exit 12
    #fi
else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Backup of $APP_CODE has finalized"
    echo ""
fi

#########################################################
# DEPLOY BASE DE DATOS                                  #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Install BBDD ${TAG}"
deploy-bbdd "INSTALL"
ret=$?
if [ $ret -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t install BBDD $INSTALABLE_BATCH (Rollback required)"
    deploy-bbdd "ROLLBACK"
    ret_rollback_bbdd=$?
    startServer "INSTALL"
    ret_start_server=$?
    if [ "$ret_rollback_bbdd" -ne 0 ] || [ "$ret_start_server" -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Automtic rollback problems. Check enviroment !!!"
	exit 1
    else
	echo `date "+%Y-%m-%d %H:%M:%S"`"|INFO|Rollback executed."
	exit 1
    fi   
    exit $ret
else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Install BBDD ${TAG}"
    echo ""
fi

#########################################################
# DEPLOY BATCH                                          #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Install BATCH ${TAG}"
deploy-batch "INSTALL"
ret=$?
if [ $ret -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t install BATCH $INSTALABLE_BATCH (Rollback required)"
    deploy-bbdd "ROLLBACK"
    ret_rollback_bbdd=$?
    deploy-batch "ROLLBACK"
    ret_rollback_batch=$?
    startServer "INSTALL"
    ret_start_server=$?
    if [ "$ret_rollback_bbdd" -ne 0 ] || [ "$ret_rollback_batch" -ne 0 ] || [ "$ret_start_server" -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Automtic rollback problems. Check enviroment !!!"
	exit 1
    else
	echo `date "+%Y-%m-%d %H:%M:%S"`"|INFO|Rollback executed."
	exit 1
    fi    
    exit $ret
else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Install BATCH ${TAG}"
    echo ""
fi


#########################################################
# DESPLEGAR VERSION APLICACION ONLINE                   #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Begining the deployment of $TAG"
deploy-ear "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems during the deployment process of $APP_CODE"
    deploy-ear "ROLLBACK"
    retVal=$?
    if [ "$retVal" -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems starting server for app $APP_CODE"
	exit $retVal
    else   
	echo `date "+%Y-%m-%d %H:%M:%S"`"|WARN|Started server for app $APP_CODE, the deployment has failed!!!"
	exit 1
    fi

else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Deploy of $TAG has finalized"
    echo ""
fi

#########################################################
# ARRANQUE DE APLICACION ONLINE                         #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Starting server for app $APP_CODE"
startServer "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    
    startServer "ROLLBACK"
    retVal=$?

    if [ "$retVal" -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems starting server for app $APP_CODE"
	exit $retVal
	#else
	# Un rollback en el arranque generará incidencia siempre
	#echo " >> FINAL ROLLBACK ARRANQUE DE SERVIDOR APP : $APP_CODE"
    fi

else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Started server for app $APP_CODE"
    echo ""
fi

#########################################################
# COPIA FICHERO VERSION                                 #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Copying version file for app $APP_CODE"
finish-deploy "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    
    finish-deploy "ROLLBACK"
    retVal=$?

    if [ "$retVal" -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems copying version file for app $APP_CODE"
	exit $retVal
	#else
	# Un rollback en el arranque generará incidencia siempre
	#echo " >> FINAL ROLLBACK ARRANQUE DE SERVIDOR APP : $APP_CODE"
    fi

else
    echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Copying version file for app $APP_CODE"
    echo ""
fi

echo `date "+%Y-%m-%d %H:%M:%S"`"|END-GLOBAL|Deployment TAG : "$TAG

exit 0

##########################################################
# FUNCIONES AUXILIARES                                   #
##########################################################

#---------------------------------
#	FUNCTION: checkArtifact
#
#	 PURPOSE: 
#---------------------------------
checkArtifact()
{
    FICHERO=$1
    #Comprobar que existen los artefactos a instalar
    if [ `ssh -o StrictHostKeyChecking=no $ARTIFACT_REPO "find /rep_instalables/$GROUP_ID/ -name $FICHERO |wc -l"` -eq 1 ]; then 
	ORIGEN=`ssh -o StrictHostKeyChecking=no $ARTIFACT_REPO "find /rep_instalables/$GROUP_ID/ -name $FICHERO"`
    	exit $?
    fi  
}

#---------------------------------
#	FUNCTION: stopServer
#
#	 PURPOSE: 
#---------------------------------
stopServer()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/stop-server.sh $APP_CODE" 2>&1 >/dev/null
        retVal=$?
    else
        # En caso de error de parada no nos planteamos ROLLBACK
        retVal=0
    fi
    return "$retVal"
}

#---------------------------------
#	FUNCTION: startServer
#
#	 PURPOSE: 
#---------------------------------
startServer()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/start-server.sh $APP_CODE" 2>&1 >/dev/null
        retVal=$?
    else
        retVal=1
    fi
    return "$retVal"
}

#---------------------------------
#	FUNCTION: deploy-ear
#
#	 PURPOSE: 
#---------------------------------
deploy-ear()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/deploy-ear.sh $APP_CODE $TAG.ear" 2>&1 >/dev/null
        retVal=$?
    else
        startServer "INSTALL"
        retVal=$?
    fi
    return "$retVal"
}

#---------------------------------
#	FUNCTION: backup-ear
#
#	 PURPOSE: 
#---------------------------------
backup-ear()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/backup-ear-conf.sh $APP_CODE" 2>&1 >/dev/null
        retVal=$?
    else
        echo `date "+%Y-%m-%d %H:%M:%S"`"|INFO|Starting server for app $APP_CODE"
        
        startServer "INSTALL"        
        retVal=$?
        if [ "$retVal" -ne 0 ]; then
            echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t start server for app $APP_CODE!!!!"
            exit $retVal
        else
            echo `date "+%Y-%m-%d %H:%M:%S"`"|WARN|Started server for app $APP_CODE, the deployment has failed!!!"
            exit 1
        fi
    fi
    return "$retVal"
}

#---------------------------------
#	FUNCTION: deploy-bbdd
#
#	 PURPOSE: 
#---------------------------------
deploy-bbdd () 
{
    retVal=0 
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/deploy-bbdd.sh $PO_CODE $INSTALABLE_BATCH $BATCH_DIR $APP_CODE $ENV"
        retVal=$?
    elif [ $1 == "ROLLBACK" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S"`"|START|BBDD rollback $APP_CODE"
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/rollback-bbdd.sh $PO_CODE $INSTALABLE_BATCH $BATCH_DIR $APP_CODE $ENV"
        retVal=$?
        echo `date "+%Y-%m-%d %H:%M:%S"`"|END|BBDD rollback $APP_CODE"            
    fi
    return "$retVal"
}

#---------------------------------
#	FUNCTION: deploy-batch
#
#	 PURPOSE: 
#---------------------------------
deploy-batch ()
{
    retVal=0 
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/deploy-batch.sh $PO_CODE $INSTALABLE_BATCH $BATCH_DIR $APP_CODE"
        retVal=$?
    elif [ $1 == "ROLLBACK" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Batch rollback $APP_CODE"
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/rollback-batch.sh $PO_CODE $INSTALABLE_BATCH $BATCH_DIR $APP_CODE"
        retVal=$?
        echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Batch rollback $APP_CODE"            
    fi
    return "$retVal"
}

#---------------------------------
#	FUNCTION: finish-deploy
#
#	 PURPOSE: 
#---------------------------------
finish-deploy () 
{
    retVal=0 
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/finish-deploy.sh $PO_CODE $INSTALABLE_BATCH $BATCH_DIR $APP_CODE"
        retVal=$?
    elif [ $1 == "ROLLBACK" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Version file copy error $APP_CODE"       
        retVal=0
        echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Version file copy error $APP_CODE"            
    fi
    return "$retVal"
}

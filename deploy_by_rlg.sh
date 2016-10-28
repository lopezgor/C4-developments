#====================================================================================================================================================
#
#        FILE: deploy.sh
#
#       USAGE: ./deploy.sh [PARAMETERS]
#
#  PARAMETERS: + PO_CODE · Projects Office Code
#	       + APP_CODE · APPlication Code
#	       + TAG · deprecated, not more in use!!! 
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
#		+ Section One: an initial section for making up the name of the differents artficats to be deployed considering two approachings ('DEPLOY_METHOD')
#			+ V1 (LEGACY): the actual deployment invocation
#			+ V2 (CINTEGRATION): the location 
#		+ Section Two: carrying out of deployment and possible rollback case of error
#
#  PARAMETROS: 
#	        
#====================================================================================================================================================

clear;                                             

if [ $# -lt 12 ]; then
    # Delete of TAG parameter
    # echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|12 Parameters are required for deploy a TAG : PO_CODE, APP_CODE, TAG, ENV, DEPLOY_CONFIG, ENV_DIR, ENV_BATCH, BATCH_HOST, JBOSS_HOST, DEPLOY_METHOD, ARTIFACT_ID, GROUP_ID"
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|12 Parameters are required for deploying a TAG : PO_CODE, APP_CODE, ENV, DEPLOY_CONFIG, ENV_DIR, ENV_BATCH, BATCH_HOST, JBOSS_HOST, DEPLOY_METHOD, ARTIFACT_ID, GROUP_ID"
    exit 1
fi

#----------------------------------------------------------
#
# SECTION ONE
#
#	Artifacts Name Making up through DEPLOY_METHOD type
#
#----------------------------------------------------------

#----------------------------------------------------------
# CONSTANTS initialization
#----------------------------------------------------------
LEGACY_DEPLOY_MODE="V1"
CINTEGRATION_DEPLOY_MODE="V2"

#----------------------------------------------------------
# Variables assignment through parameters input
#----------------------------------------------------------
echo "###################################################"
echo " + COMIENZO DEPLOY"
echo " + PARAMETROS : "
echo " +          PO_CODE = "$PO_CODE 
echo " +           COD_AP = "$COD_AP
#echo " +              TAG = "$TAG
echo " +             SERV = "$SERV
echo " +             OPER = "$BATCH_HOST
echo " +            JBOSS = "$JBOSS_HOST
echo " +    DEPLOY_CONFIG = "$DEPLOY_CONFIG
echo " +        BATCH_DIR = "$BATCH_DIR
echo " +              ENV = "$ENV
echo " +       BATCH_HOST = "$BATCH_HOST
echo " +       JBOSS_HOST = "$JBOSS_HOST
echo " +    DEPLOY_METHOD = "$DEPLOY_METHOD
echo " +    ARTIFACT_REPO = "$ARTIFACT_REPO
echo " +          VERSION = "$VERSION
echo " +      ARTIFACT_ID = "$ARTIFACT_ID
echo " +         GROUP_ID = "$GROUP_ID
echo "###################################################"

echo "BEGIN of Artifact Name Making Up"

#-- DEPLOY_METHOD Compliance Checking
echo $LEGACY_DEPLOY_MODE" "$CINTEGRATION_DEPLOY_MODE | grep -q $DEPLOY_METHOD
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Deploy method values must be V1 or V2"
    exit 1      
fi     

#----------------------------------------------------------
# Artifacts Name  according to DEPLOY_METHOD
#----------------------------------------------------------

# BEGIN of - Common to the two DEPLOY_METHOD variants - #

#--------------------------------------
# INSTALABLE_BATCH Initialization
#--------------------------------------
INSTALABLE_BATCH=${VERSION//_ES/InstalablesSH_ES}".zip"  # Find and replace all (//) ocurrence of '_ES' with 'InstalablesSH_Es' within the VERSION literal

#--------------------------------------
# TAG Initialization
#--------------------------------------
TAG=$VERSION  # With the V1 version, VERSION includes the full file name needed by TAG

#--------------------------------------
# CONFIG_APP Initialization
#--------------------------------------
CONFIG_APP=${TAG//_ES/Configuration_ES}".rar"  # CONFIG_APP doesn't change between V1 and V2

# END of - Common to the two DEPLOY_METHOD variants - #


if [ $DEPLOY_METHOD = $CINTEGRATION_DEPLOY_MODE ]; then
    # With V2 TAG is formed with the conjunction of ARTIFACT_ID and VERSION 
    TAG=$ARTIFACT_ID_$VERSION
    
    # INSTALABLE_BATCH Artifact existence check
    check_artifact $INSTALABLE_BATCH
    ret_instalable=$?
    
    # EAR Artifact existence check
    check_artifact $ARTIFACTID_$VERSION.ear
    ret_ear=$?
    
    # CONFIG_APP Artifact existence check
    check_artifact $CONFIG_APP
    ret_config=$?
    
    if [ "$ret_instalable" -ne 0 ] || [ "$ret_config" -ne 0 ] || [ "$ret_ear" -ne 0 ]; then
	echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Failure to find artifacts."
	exit 1
    fi 
fi    

echo "END of Artifact Name Making Up"
exit 0

#----------------------------------------------------------
# Invocation of 'init-deploy.sh' on the BATCH_HOST in order to check the compliance
#----------------------------------------------------------
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

#----------------------------------------------------------
# EAR Downloading
#----------------------------------------------------------
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

#----------------------------------------------------------
# Configuration Online Downloading
#----------------------------------------------------------
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

#----------------------------------------------------------
# INSTALABLE_BATCH Downloading
#----------------------------------------------------------
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

#----------------------------------------------------------
# Stopping Application Server
#----------------------------------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Stoping server for app $APP_CODE"
stop_server "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems stoping server for app $APP_CODE"

    stopServer "ROLLBACK" # rgordo: Que sentido tiene? no tiene contemplado siquiera ese parametro en la funcion.

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

#-----------------------------------------------
# Online EAR Backuping
#-----------------------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Begining the backup of $APP_CODE"
backup_ear "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems during the backup process of $APP_CODE"
    backup_ear "ROLLBACK"
    retVal=$?
    # Por aqui nunca entraria, en rollback de backup_ear siempre se hace un exit.
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

#-----------------------------------------------
# DB Deploying
#-----------------------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Install BBDD ${TAG}"
deploy_bbdd "INSTALL"
ret=$?
if [ $ret -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t install BBDD $INSTALABLE_BATCH (Rollback required)" # rgordo: realmente la parte de BBDD es de la parte BATCH?
    deploy_bbdd "ROLLBACK"
    ret_rollback_bbdd=$?
    start_server "INSTALL" # rgordo: el start_server 
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

#-----------------------------------------------
# BATCH Deploying
#-----------------------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Install BATCH ${TAG}"
deploy_batch "INSTALL"
ret=$?
if [ $ret -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t install BATCH $INSTALABLE_BATCH (Rollback required)"
    deploy_bbdd "ROLLBACK"
    ret_rollback_bbdd=$?
    deploy_batch "ROLLBACK"
    ret_rollback_batch=$?
    start_server "INSTALL"
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


#-----------------------------------------------
# EAR Deploying
#-----------------------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Begining the deployment of $TAG"
deploy_ear "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems during the deployment process of $APP_CODE"
    deploy_ear "ROLLBACK"
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

#-----------------------------------------------
# APP SERVER Start
#-----------------------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Starting server for app $APP_CODE"
start_server "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    
    start_server "ROLLBACK"
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

#-----------------------------------------------
# VERSION FILE Copy
#-----------------------------------------------
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Copying version file for app $APP_CODE"
finish_deploy "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
    
    finish_deploy "ROLLBACK"
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

#=============================================================================
# AUXILIARY FUNCTIONS
#=============================================================================

#=== FUNCTION ================================================================
# NAME: check_artifact
# DESCRIPTION: 
# PARAMETER 1: ---
#=============================================================================
check_artifact()
{
    FICHERO=$1
    #Comprobar que existen los artefactos a instalar
    if [ `ssh -o StrictHostKeyChecking=no $ARTIFACT_REPO "find /rep_instalables/$GROUP_ID/ -name $FICHERO |wc -l"` -eq 1 ]; then 
	ORIGEN=`ssh -o StrictHostKeyChecking=no $ARTIFACT_REPO "find /rep_instalables/$GROUP_ID/ -name $FICHERO"`
    	exit $?
    fi  
}

#=== FUNCTION ================================================================
# NAME: stop_server
# DESCRIPTION: 
# PARAMETER 1: ---
#=============================================================================
stop_server()
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

#=== FUNCTION ================================================================
# NAME: start_server
# DESCRIPTION: 
# PARAMETER 1: ---
#=============================================================================
start_server()
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

#=== FUNCTION ================================================================
# NAME: deploy_ear
# DESCRIPTION: 
# PARAMETER 1: ---
#=============================================================================
deploy_ear()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/deploy-ear.sh $APP_CODE $TAG.ear" 2>&1 >/dev/null
        retVal=$?
    else
        start_server "INSTALL"
        retVal=$?
    fi
    return "$retVal"
}

#=== FUNCTION ================================================================
# NAME: backup_ear
# DESCRIPTION: 
# PARAMETER 1: ---
#=============================================================================
backup_ear()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/backup-ear-conf.sh $APP_CODE" 2>&1 >/dev/null
        retVal=$?
    else
        echo `date "+%Y-%m-%d %H:%M:%S"`"|INFO|Starting server for app $APP_CODE"
        
        start_server "INSTALL"        
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

#=== FUNCTION ================================================================
# NAME: deploy_bbdd
# DESCRIPTION: 
# PARAMETER 1: ---
#=============================================================================
deploy_bbdd () 
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

#=== FUNCTION ================================================================
# NAME: deploy_batch
# DESCRIPTION: 
# PARAMETER 1: ---
#=============================================================================
deploy_batch ()
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

#=== FUNCTION ================================================================
# NAME: finish_deploy
# DESCRIPTION: 
# PARAMETER 1: ---
#=============================================================================
finish_deploy () 
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

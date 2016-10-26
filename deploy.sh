clear;                                             

if [ $# -lt 12 ]; then    
     echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|9 Parameters are required for deploy a TAG : COD_OP, COD_APP, VERSION, ENV, CONF, ENV_DIR, ENV_BATCH, BATCH_HOST, JBOSS_HOST, DEPLOY_METHOD, ARTIFACTID, GROUPID"
     exit 1
fi


###################################################
# RECOGEMOS LOS PARAMETROS DEL SCRIPT             #
###################################################
LEGACY_DEPLOY_MODE="V1"
CINTEGRATION_DEPLOY_MODE="V2"
COD_OP=$1
COD_APP=$2
TAG=$3
SERV=$4
CONF=$5
ENTORNO_DIR=$6
ENTORNO=$7
BATCH_HOST=$8
JBOSS_HOST=$9
DEPLOY_METHOD=${10}
ARTIFACTREPOSITORY=${11}
VERSION=${12}
ARTIFACTID=${13}
GROUPID=${14}

echo "###################################################"
echo " + COMIENZO DEPLOY"
echo " + PARAMETROS : "
echo " +    COD_OP              = "$COD_OP
echo " +    TAG                 = "$TAG
echo " +    SERV                = "$SERV
echo " +    OPER                = "$BATCH_HOST
echo " +    JBOSS               = "$JBOSS_HOST
echo " +    CONF                = "$CONF
echo " +    ENTORNO_DIR         = "$ENTORNO_DIR
echo " +    ENTORNO             = "$ENTORNO
echo " +    BATCH_HOST          = "$BATCH_HOST
echo " +    JBOSS_HOST          = "$JBOSS_HOST
echo " +    DEPLOY_METHOD       = "$DEPLOY_METHOD
echo " +    ARTIFACTREPOSITORY  = "$ARTIFACTREPOSITORY
echo " +    VERSION             = "$VERSION
echo " +    ARTIFACTID          = "$ARTIFACTID
echo " +    GROUPID             = "$GROUPID
echo "###################################################"

checkArtifact()
{
    FICHERO=$1
    #Comprobar que existen los artefactos a instalar
    if [ `ssh -o StrictHostKeyChecking=no $ARTIFACTREPOSITORY "find /rep_instalables/$GROUPID/ -name $FICHERO |wc -l"` -eq 1 ]; then 
      ORIGEN=`ssh -o StrictHostKeyChecking=no $ARTIFACTREPOSITORY "find /rep_instalables/$GROUPID/ -name $FICHERO"`
    	exit $?
   fi  
}

#comprueba que se indica el modo de despliegue correctamente
echo $LEGACY_DEPLOY_MODE" "$CINTEGRATION_DEPLOY_MODE | grep -q $DEPLOY_METHOD
retVal=$?
if [ "$retVal" -ne 0 ]; then
  echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Deploy method values must be V1 or V2"
  exit 1      
fi     

 
if [ $DEPLOY_METHOD = $LEGACY_DEPLOY_MODE ]; then
    #inicializa el instalable
    INSTALABLE_BATCH=${VERSION//_ES/InstalablesSH_ES}".zip"
elif [ $DEPLOY_METHOD = $CINTEGRATION_DEPLOY_MODE ]; then
    #copia los artefactos del bote de integracion continua al bote del generador de instalables
    #y verifica que 
    TAG=$ARTIFACTID_$VERSION
    INSTALABLE_BATCH=${VERSION//_ES/InstalablesSH_ES}".zip"
    CONFIG_APP=${TAG//_ES/Configuration_ES}".rar"
    EAR=$ARTIFACTID_$VERSION.ear
    
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

##########################################################
# INIT DEPLOY COMPRUEBA QUE SE PUEDE DESPLEGAR           #
##########################################################
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Init deploy $COD_APP $TAG"
ssh -t iecontin@$BATCH_HOST "sudo -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/init-deploy.sh $COD_OP $INSTALABLE_BATCH $ENTORNO_DIR $COD_APP $ENTORNO"
retVal=$?
if [ "$retVal" -ne 0 ]; then
   echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t init deploy, check enviroment!!!!"
   exit $retVal
fi
echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Init deploy $COD_APP"   


echo `date "+%Y-%m-%d %H:%M:%S"`"|START-GLOBAL|Deployment TAG : "$TAG
echo ""

##########################################################
# FUNCIONES AUXILIARES                                   #
##########################################################
stopServer()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/stop-server.sh $COD_APP" 2>&1 >/dev/null
        retVal=$?
    else
        # En caso de error de parada no nos planteamos ROLLBACK
        retVal=0
    fi
    return "$retVal"
}

startServer()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/start-server.sh $COD_APP" 2>&1 >/dev/null
        retVal=$?
    else
        retVal=1
    fi
    return "$retVal"
}

deploy-ear()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/deploy-ear.sh $COD_APP $TAG.ear" 2>&1 >/dev/null
        retVal=$?
    else
        startServer "INSTALL"
        retVal=$?
    fi
    return "$retVal"
}

backup-ear()
{
    retVal=0
    
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/backup-ear-conf.sh $COD_APP" 2>&1 >/dev/null
        retVal=$?
    else
        echo `date "+%Y-%m-%d %H:%M:%S"`"|INFO|Starting server for app $COD_APP"
        
        startServer "INSTALL"        
        retVal=$?
        if [ "$retVal" -ne 0 ]; then
           echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t start server for app $COD_APP!!!!"
           exit $retVal
        else
           echo `date "+%Y-%m-%d %H:%M:%S"`"|WARN|Started server for app $COD_APP, the deployment has failed!!!"
           exit 1
        fi
    fi
    return "$retVal"
}

deploy-bbdd () 
{
    retVal=0 
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/deploy-bbdd.sh $COD_OP $INSTALABLE_BATCH $ENTORNO_DIR $COD_APP $ENTORNO"
        retVal=$?
    elif [ $1 == "ROLLBACK" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S"`"|START|BBDD rollback $COD_APP"
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/rollback-bbdd.sh $COD_OP $INSTALABLE_BATCH $ENTORNO_DIR $COD_APP $ENTORNO"
        retVal=$?
        echo `date "+%Y-%m-%d %H:%M:%S"`"|END|BBDD rollback $COD_APP"            
    fi
    return "$retVal"
}

deploy-batch ()
{
    retVal=0 
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/deploy-batch.sh $COD_OP $INSTALABLE_BATCH $ENTORNO_DIR $COD_APP"
        retVal=$?
    elif [ $1 == "ROLLBACK" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Batch rollback $COD_APP"
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/rollback-batch.sh $COD_OP $INSTALABLE_BATCH $ENTORNO_DIR $COD_APP"
        retVal=$?
        echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Batch rollback $COD_APP"            
    fi
    return "$retVal"
}

finish-deploy () 
{
    retVal=0 
    if [ $1 == "INSTALL" ]; then    
        ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin HOMESMS=/home1/smsexp -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/finish-deploy.sh $COD_OP $INSTALABLE_BATCH $ENTORNO_DIR $COD_APP"
        retVal=$?
    elif [ $1 == "ROLLBACK" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Version file copy error $COD_APP"       
        retVal=0
        echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Version file copy error $COD_APP"            
    fi
    return "$retVal"
}
 

#########################################################
# DESCARGA DE EAR                                       #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Downloading EAR file $TAG.ear"
ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/get-qa-files.sh $COD_APP $TAG.ear" 2>&1 >/dev/null
ret=$?
if [ $ret -ne 0 ]; then
   echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t download $TAG.ear (Rollback no required)"
   #No hay rollback, no se ha instalado nada.
   exit $ret
else
   echo `date "+%Y-%m-%d %H:%M:%S"`"|END|File downloaded $TAG.ear"
   echo ""
fi

#########################################################
# DESCARGA DE CONFIGURACION                             #
if [ $CONF == "SI" ]; then
    CONFIG_APP=${TAG//_ES/Configuration_ES}".rar"	
    echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Downloading EAR config. file $CONFIG_APP"
    ssh -t iecontin@$JBOSS_HOST "sudo -u uwassrv /opt/apps/carrefour/scripts/integracion_continua/JBOSS/get-qa-files.sh $COD_APP $CONFIG_APP" 2>&1 >/dev/null
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

#########################################################
# DESCARGA DE INSTALABLES BATCH                         #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Downloading InstalableSH file $INSTALABLE_BATCH"
ssh -t iecontin@$BATCH_HOST "sudo PATH=$PATH:.:/usr/local/bin -u ubatch /opt/apps/carrefour/scripts/integracion_continua/BATCH/get-qa-files.sh $COD_OP $INSTALABLE_BATCH $ENTORNO_DIR $COD_APP"
ret=$?
if [ $ret -ne 0 ]; then
   echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Can\`t download $INSTALABLE_BATCH (Rollback no required)"
   #No hay rollback, no se ha instalado nada.
   exit $ret
else
   echo `date "+%Y-%m-%d %H:%M:%S"`"|END|File downloaded $INSTALABLE_BATCH"
   echo ""
fi


#########################################################
# PARADA DE APLICACION ONLINE                           #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Stoping server for app $COD_APP"
stopServer "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
   echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems stoping server for app $COD_APP"
   stopServer "ROLLBACK"
   retVal=$?
   if [ "$retVal" -ne 0 ]; then
      echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems starting server for app $COD_APP"
      exit $retVal
   else
      echo `date "+%Y-%m-%d %H:%M:%S"`"|WARN|Started server for app $COD_APP, the deployment has failed!!!"
      exit 1
   fi
else
   echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Stoped server for app $COD_APP"
   echo ""
fi

#########################################################
# BACKUP DE APLICACION ONLINE                           #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Begining the backup of $COD_APP"
backup-ear "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
   echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems during the backup process of $COD_APP"
   backup-ear "ROLLBACK"
   retVal=$?
   # Por aqui nunca entraria, en rollback de backup-ear siempre se hace un exit.
   #if [ "$retVal" -ne 0 ]; then
   #   echo "    >> ERROR ($retVal) BACKUP APP : $COD_APP"
   #   exit $retVal
   #else
   #   echo " >> FINAL ROLLBACK APP : $COD_APP"
   #   exit 12
   #fi
else
   echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Backup of $COD_APP has finalized"
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
   echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems during the deployment process of $COD_APP"
   deploy-ear "ROLLBACK"
   retVal=$?
   if [ "$retVal" -ne 0 ]; then
      echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems starting server for app $COD_APP"
      exit $retVal
   else   
      echo `date "+%Y-%m-%d %H:%M:%S"`"|WARN|Started server for app $COD_APP, the deployment has failed!!!"
      exit 1
   fi

else
   echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Deploy of $TAG has finalized"
   echo ""
fi

#########################################################
# ARRANQUE DE APLICACION ONLINE                         #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Starting server for app $COD_APP"
startServer "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
   
   startServer "ROLLBACK"
   retVal=$?

   if [ "$retVal" -ne 0 ]; then
      echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems starting server for app $COD_APP"
      exit $retVal
   #else
      # Un rollback en el arranque generará incidencia siempre
      #echo " >> FINAL ROLLBACK ARRANQUE DE SERVIDOR APP : $COD_APP"
   fi

else
   echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Started server for app $COD_APP"
   echo ""
fi

#########################################################
# COPIA FICHERO VERSION                                 #
echo `date "+%Y-%m-%d %H:%M:%S"`"|START|Copying version file for app $COD_APP"
finish-deploy "INSTALL"
retVal=$?
if [ "$retVal" -ne 0 ]; then
   
   finish-deploy "ROLLBACK"
   retVal=$?

   if [ "$retVal" -ne 0 ]; then
      echo `date "+%Y-%m-%d %H:%M:%S"`"|ERROR|Problems copying version file for app $COD_APP"
      exit $retVal
   #else
      # Un rollback en el arranque generará incidencia siempre
      #echo " >> FINAL ROLLBACK ARRANQUE DE SERVIDOR APP : $COD_APP"
   fi

else
   echo `date "+%Y-%m-%d %H:%M:%S"`"|END|Copying version file for app $COD_APP"
   echo ""
fi

echo `date "+%Y-%m-%d %H:%M:%S"`"|END-GLOBAL|Deployment TAG : "$TAG

exit 0
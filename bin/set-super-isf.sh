#!/bin/bash
# example: fourISF.sh 29 22 19 17 100 140 190 30
#
# input params:
isfNormal=$1
isfStrong=$2
isfHyper=$3
isfRage=$4
which=""
strongThreshold=$5
hyperThreshold=$6
rageThreshold=$7
maxSMBMinutes=$8
if [ -z  "$8" ]; then
    echo "usage: $0 <isfNormal> <isfStrong> <isfHyper> <isfRage> <strongThreshold> <hyperThreshold> <rageThreshold> <maxSMBMinutes>"
    echo "error: $0 requires parameters, exiting."
    exit 1
fi
# constants:
preferencesFile=/root/myopenaps/preferences.json
profileFile=/root/myopenaps/settings/autotune.json
profileFile2=/root/myopenaps/autotune/profile.json
# debug:
#preferencesFile=/root/test/preferences.json
#profileFile=/root/test/autotune.json
#profileFile2=/root/test/profile.json
# more constants:
preferencesTemp=/tmp/4preferences.json
profileTemp=/tmp/4autotune.json
# execute:
date
if [ -z  "$which" ]; then
   glucose=`jq ".[0].glucose" /root/myopenaps/monitor/glucose.json`
   if [ $(bc <<< "$glucose >= $strongThreshold") -eq 1 ]; then
      if [ $(bc <<< "$glucose >= $hyperThreshold") -eq 1 ]; then
         if [ $(bc <<< "$glucose >= $rageThreshold") -eq 1 ]; then
            which="rage"
         else
            which="hyper"
         fi
      else
         which="strong"
      fi
   else
      which="normal"
   fi
   echo "glucose=$glucose, using $which isf"
fi
jq ".sensitivity_raises_target = false | .maxSMBBasalMinutes = 1 | .maxUAMSMBBasalMinutes = 1" $preferencesFile > $preferencesTemp.normal
jq ".sensitivity_raises_target = true | .maxSMBBasalMinutes = $maxSMBMinutes | .maxUAMSMBBasalMinutes = $maxSMBMinutes" $preferencesFile > $preferencesTemp.strong
jq ".sensitivity_raises_target = true | .maxSMBBasalMinutes = $maxSMBMinutes | .maxUAMSMBBasalMinutes = $maxSMBMinutes" $preferencesFile > $preferencesTemp.hyper
jq ".sensitivity_raises_target = true | .maxSMBBasalMinutes = $maxSMBMinutes | .maxUAMSMBBasalMinutes = $maxSMBMinutes" $preferencesFile > $preferencesTemp.rage
autosens=`jq .ratio ~/myopenaps/settings/autosens.json`
echo "isfNormal = $isfNormal"
echo "isfStrong = $isfStrong"
echo "isfHyper = $isfHyper"
echo "isfRage = $isfRage"
echo "autosens=$autosens"
isfScaledNormal=$(bc -l <<< "$isfNormal * $autosens")
isfScaledStrong=$(bc -l <<< "$isfStrong * $autosens")
isfScaledHyper=$(bc -l <<< "$isfHyper * $autosens")
isfScaledRage=$(bc -l <<< "$isfRage * $autosens")
jq ".sens = ${isfScaledNormal} | .isfProfile.sensitivities[0].sensitivity = ${isfScaledNormal}" $profileFile > $profileTemp.normal
jq ".sens = ${isfScaledStrong} | .isfProfile.sensitivities[0].sensitivity = ${isfScaledStrong}" $profileFile > $profileTemp.strong
jq ".sens = ${isfScaledHyper} | .isfProfile.sensitivities[0].sensitivity = ${isfScaledHyper}" $profileFile > $profileTemp.hyper
jq ".sens = ${isfScaledRage} | .isfProfile.sensitivities[0].sensitivity = ${isfScaledRage}" $profileFile > $profileTemp.rage
echo "isfScaledNormal = $isfScaledNormal"
echo "isfScaledStrong = $isfScaledStrong"
echo "isfScaledHyper = $isfScaledHyper"
echo "isfScaledRage = $isfScaledRage"
echo "using $which isf"
# copy (change profile first to ensure ISF is weakened before target lowered):
diff $profileTemp.$which $profileFile
if [ $? != 0 ]
then
   echo "installing $which profile"
   cp $profileTemp.$which $profileFile
   cp $profileFile $profileFile2
else
   echo "already using $which profile"
fi
diff $preferencesTemp.$which $preferencesFile
if [ $? != 0 ]
then
   echo "installing $which preferences"
   cp $preferencesTemp.$which $preferencesFile
else
   echo "already using $which preferences"
fi
# done.

#!/bin/bash
# example: fourISF.sh 80 100 60 30

# super ISF
function computeSuperIsf {

	# just use smallest basal rate for now, can get from profile later
	assumedBasalRate=1.1
	strongestSafeSuperIsf=35
	stolenMinutesPerMgdl=$(bc <<<"scale=2;0.75")
	
	targetBg=`jq .max_bg $profileFile`
	bg=`jq ".[0].glucose" /root/myopenaps/monitor/glucose.json`
	deltaBg=$(bc <<<"scale=2;$bg-$targetBg")
	
	stolenMinutes=$(bc <<<"scale=2;$deltaBg*$stolenMinutesPerMgdl")
	desiredStolenCorrectionUnits=$(bc <<<"scale=2;$assumedBasalRate*$stolenMinutes/60")
	superIsf=$(bc <<<"scale=2;$deltaBg / ( ($deltaBg / $isfNormal) + $desiredStolenCorrectionUnits)")
	roundedSuperIsf=$(bc <<<"($superIsf+.5)/1")
	
	safeSuperIsf=$roundedSuperIsf
	if ((roundedSuperIsf < strongestSafeSuperIsf)); then
	  safeSuperIsf=$strongestSafeSuperIsf
	fi
	
	# just for logging
	normalCorrectionUnits=$(bc <<<"scale=2;$deltaBg / $isfNormal")
	totalCorrectionUnits=$(bc <<<"scale=2;$deltaBg / $safeSuperIsf")
	# actual may be less than desired because strongestSafeSuperIsf limited the stolen correction units
	actualStolenCorrectionUnits=$(bc <<<"scale=2;$totalCorrectionUnits-$normalCorrectionUnits")
	
	echo "using constants isfNormal: $isfNormal, strongestSafeSuperIsf: $strongestSafeSuperIsf, assumedBasalRate: $assumedBasalRate, stolenMinutesPerMgdl: $stolenMinutesPerMgdl"
	echo "bg is $bg, targetBg is $targetBg, deltaBg is $deltaBg"
	echo "stolenMinutes is $stolenMinutes, superIsf is $superIsf, roundedSuperIsf is $roundedSuperIsf, safeSuperIsf is $safeSuperIsf"
	echo "normalCorrectionUnits is $normalCorrectionUnits, desiredStolenCorrectionUnits is $desiredStolenCorrectionUnits, actualStolenCorrectionUnits is $actualStolenCorrectionUnits, totalCorrectionUnits is $totalCorrectionUnits"

    return $safeSuperIsf
}

isfNormal=$1
which=""
strongThreshold=$2
maxSMBMinutes=$3
maxUAMSMBMinutes=$4
if [ -z  "$4" ]; then
    echo "usage: $0 <isfNormal> <strongThreshold> <maxSMBMinutes> <maxUAMSMBMinutes>"
    echo "error: $0 requires parameters, exiting."
    exit 1
fi

# constants:
preferencesFile=/root/myopenaps/preferences.json
profileFile=/root/myopenaps/settings/autotune.json
profileFile2=/root/myopenaps/autotune/profile.json
profileFileWithTempTargets=/root/myopenaps/settings/profile.json
preferencesTemp=/tmp/4preferences.json
profileTemp=/tmp/4autotune.json
# execute:
date
if [ -z  "$which" ]; then
   glucose=`jq ".[0].glucose" /root/myopenaps/monitor/glucose.json`
   tempTargetSet=`jq ".bg_targets.targets[1].temptargetSet" /root/myopenaps/settings/profile.json`
   echo "tempTargetSet=$tempTargetSet"
   if [ "$tempTargetSet" = "true" ]; then
      echo "using normal because temp target set"
      which="normal"
   elif ((glucose < strongThreshold)); then
      echo "using normal because glucose below strong threshold"
      which="normal"
   else
      echo "using strong because glucose above strong threshold and no temp target set"
      which="strong"
   fi
   echo "glucose=$glucose, using $which isf"
fi

jq ".maxSMBBasalMinutes = 1 | .maxUAMSMBBasalMinutes = 1" $preferencesFile > $preferencesTemp.normal
jq ".maxSMBBasalMinutes = $maxSMBMinutes | .maxUAMSMBBasalMinutes = $maxUAMSMBMinutes" $preferencesFile > $preferencesTemp.strong
autosens=`jq .ratio ~/myopenaps/settings/autosens.json`
echo "isfNormal = $isfNormal"

isfStrong=$isfNormal
if [ "$which" = "strong" ]; then
   computeSuperIsf
   isfStrong=$?
fi
echo "isfStrong = $isfStrong"

echo "autosens=$autosens"
isfScaledNormal=$(bc -l <<< "$isfNormal * $autosens")
isfScaledStrong=$(bc -l <<< "$isfStrong * $autosens")

# change sensitivity of third item in array which is my daytime sensitivity
jq ".sens = ${isfScaledNormal} | .isfProfile.sensitivities[2].sensitivity = ${isfScaledNormal}" $profileFile > $profileTemp.normal
jq ".sens = ${isfScaledStrong} | .isfProfile.sensitivities[2].sensitivity = ${isfScaledStrong}" $profileFile > $profileTemp.strong

echo "isfScaledNormal = $isfScaledNormal"
echo "isfScaledStrong = $isfScaledStrong"
echo "using $which isf"

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




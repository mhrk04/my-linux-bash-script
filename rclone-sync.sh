#! /bin/bash
echo "Folder semasa :"
pwd
echo "Pastikan script ini diubah terlebih dahulu sebelum digunakan mengikut ketetapan masing2 "
echo -n "Adakah anda hendak menyelaraskan file local dengan google drive anda(y/N): "
read VAR

if [[ $VAR == "y" ]]||[[ $VAR == "" ]]
then
  echo "Cuba dengan --dry-run flag untuk melihat apa yang akan di salin"
  rclone sync ~/jelly/ MOE:Media-Server/ -P --dry-run
  echo -n "Anda yakin hendak meneruskan salinan (y/N): "
  read sah
    if [[ $sah == "y" ]]||[[ $sah == "" ]]
    then
      rclone sync ~/jelly/ MOE:Media-Server/ -P
      exit 1
    else
      echo "DIbatalkan daripada menyalin"
      exit 1
    fi
  else
   echo "Dibatalkan"
fi

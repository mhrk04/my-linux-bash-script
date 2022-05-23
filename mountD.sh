#! /bin/bash
current=$(pwd)
echo "Anda berada di dalam direktori $current"
echo "Adakah anda hendak memautkan NFS ?"
read confirm

if [[ $confirm == "y" ]]|| [[ $confirm == "Y" ]]
then
echo "Sila Masukkan IP Address server Beserta lokasi direktori :"
echo "Contoh : 192.168.7.88:/mnt/folder"
read ipadd

echo "Sila masukkan tempat untuk memaut Network Drive"
echo "Contoh : /mnt/folder"
read pathtomount
sudo mount -t nfs $ipadd $pathtomount

else
  echo "Dibatalkan daripada memaut"
      exit 1
fi      

# LTO-Backup
A lightweight utility to help you backup files to LTO tapes.

## Dependencies

* dialog (terminal UI interface)
* lsscsi (tape detection)
* mbuffer (buffering processed data to tape to prevent shoe-shining)
* mt-st (magnetic tape control)
* calc (calculate size, estimate time/tape required)

## Usage

```
git clone https://github.com/r1cebank/LTO-Backup.git && cd LTO-Backup
sudo ./backup.sh
```

Then follow the UI interface to select your tape devices and tape type (tape type only used to estimate required tape for backup)

## Backup

## Restore

## Compression

The script defaults to use zstandard `zstd` for compression, the default compression level is 10.

## Encryption

The script will prompt you for enabling encryption before backup, you can choose to let script generate random key or provide an encryption key. Encryption key is generated with the following command:

```
openssl rand 512 > encryption.key
```

## Data Layout

The script will create two file on the first tape of the backup task, the first file will contain this script and the custom config used to backup, encryption key filename will be included as well. This is used to enable future restore without the need to cloning this project. The first file including the backup script, config can be extracted with the following command once tape is inserted and at 0 block.

```
sudo tar -xvf /dev/nst0 -C [your restore location]
```
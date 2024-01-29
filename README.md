# furtrack_sync
Pulls all images from your feed. Saves metadata associated with them in the UserComment EXIF tag

## Required libs

```
apt install ruby-nokogiri ruby-jwt ruby-mini-exiftool
```

## Usage

```
cp creds.template creds.json
```

Then set your furtrack.com email & password in `creds.json`

Then run `ruby furtracksync.rb`


You can change the destination directory in the `$dest_folder ` variable at the top of the script.

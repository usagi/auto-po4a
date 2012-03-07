#!/bin/sh

add_path(){
  for p in $additional_paths
  do
    if [ -d $p ]
    then
      PATH=$p:$PATH
    fi
  done
}

configure_target(){
  target_scheme=`echo $1 | sed "s|://.*$||"`
  target_file=`basename $1`
  target_directory=${working_directory}/`echo ${1} | sed "s|^.*://||" | sed "s|/${target_file}$||"`
  ascii_file=${target_file}${additional_extension_ascii}
  po_file=${target_file}${insertional_extension_language_code}${additional_extension_po}
  translated_file=`echo ${target_file} | sed "s|\.[^.]*$||"`${insertional_extension_language_code}.`echo ${target_file} | sed "s|^.*\.||"`
}

get_alternative(){
  echo '[auto-po4a] get_alternative'
  ${base_directory}/bin/`echo $target_directory | sed "s|^${working_directory}/||" | tr / -`
}

get_source(){
  if [ "$target_scheme" = 'null' ]
  then
    echo '[auto-po4a] null scheme'
  elif [ "$target_scheme" = 'alternative' ]
  then
    get_alternative
  else
    echo "[auto-po4a] try get use $get_command"
    $get_command $get_options "${s}"
  fi
  target_charset=(`nkf --guess $target_file`)
  echo "[auto-po4a] target charset is $target_charset"
}

generate_po(){
  echo "[auto-po4a] generate_po --> $po_file"
  $po_new_command -f $po_format -m $target_file -M $target_charset -p $po_file --msgid-bugs-address "$po_msgid_bugs_address" --copyright-holder "$po_copyright_holder" --package-name "$po_package_name" --package-version "$po_package_version"
}

update_po(){
  echo "[auto-po4a] update_po --> $po_file"
  $po_update_command -f $po_format -m $ascii_file -M $target_charset -p $po_file --msgid-bugs-address "$po_msgid_bugs_address" --copyright-holder "$po_copyright_holder" --package-name "$po_package_name" --package-version "$po_package_version"
}

translate(){
  echo "[auto-po4a] translate --> $translated_file"
  $po_translate_command -f $po_format -m $ascii_file -M $target_charset -p $po_file -l $translated_file -k $po_translate_keep_ratio
}

create_target_directory(){
  echo "[auto-po4a] create_target_directory --> $target_directory"
  mkdir -p $target_directory
}

push_directory(){
  echo "[auto-po4a] push_directory --> $1"
  pushd $1
}

pop_directory(){
  echo "[auto-po4a] pop_directory"
  popd
}

update(){
  echo '[auto-po4a] update'

  for s in $sources
  do
    echo "[auto-po4a] current target is ${s}"

    configure_target $s

    if [ ! -d $target_directory ]
    then
      create_target_directory
    fi
    
    push_directory $target_directory
    
    get_source 
   
    if [ -f $po_file ]
    then
      update_po
    else
      generate_po
    fi

    translate
    
    pop_directory

  done
}

git_init(){
  echo '[auto-po4a] git_init'
  git init
}

git_pull(){
  echo '[auto-po4a] git_pull'
  git pull
}

git_add_and_commit(){
  echo '[auto-po4a] git_add_and_commit'
  git add .
  git commit -m "update: $date"
}

generate_configure(){
  if [ ! -d etc ]
  then
    mkdir -p etc
  fi
  cat > etc/auto-po4a.configure << 'EOD'
configure(){

  # time stump
  date=`date --rfc-2822`

  # http source sample
  #sources="$sources http://uncyclopedia.wikia.com/wiki/Main_Page"
  # null source sample; see also README
  #sources="$sources null://const-static/document.txt"
  # alternative source sample; see also README
  #sources="$sources alternative://alternative/test/hoge.txt"

  additional_extension_po='.po'
  insertional_extension_language_code='.ja'

  get_command='curl'
  get_options='-O'

  po_new_command='po4a-gettextize'
  po_update_command='po4a-updatepo'
  po_translate_command='po4a-translate'
  po_format='text'
  po_master_charset='utf-8'
  po_msgid_bugs_address='<ENTER YOUR EMAIL>'
  po_copyright_holder='<ENTER YOUR NAME>'
  po_package_name='<ENTER YOUR PACKAGE>'
  po_package_version=$date
  po_translate_keep_ratio=0

  working_directory='working'

  additional_paths="$additional_paths /usr/bin/vendor_perl"

  base_directory=`pwd`
}
EOD

}

load_configure(){
  echo '[auto-po4a] load_configure'
  
  if [ -d etc -a -r etc/auto-po4a.configure ]
  then
    . etc/auto-po4a.configure
  else
    
    cat << 'EOD'
It's the first running.
 Generate the etc/auto-po4a.confifure default.
 After please edit the configure file.
EOD

    generate_configure
    
    cat << 'EOD'
Note:
 This tool needs:
  po4a (must)
  wget|curl|aria2c (optional; but need for general)
  git (optional)
  perl|runhaskell|python|... (optional; for an alternative scheme if you need)
EOD
    exit 0
  fi
}

main(){
  echo '[auto-po4a] start'
  load_configure
  configure
  if [ ! -d .git ]
  then
    git_init
  elif [ `git config remote.origin.url` ]
  then
    git_pull
  fi
  add_path
  update
  if [ -d .git ]
  then
    git_add_and_commit
  fi
  echo '[auto-po4a] to exit'
}

main


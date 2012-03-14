#!/bin/sh

cout(){
  echo '[30m[40m[36m[auto-po4a][0m '$1
}

cerr(){
  echo '[25m[50m[35m[auto-po4a][0m '$1
}

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
  target_file_extension=`echo ${target_file} | sed "s|^.*\.||"`
  if [ "${target_file_extension}" = "${target_file}" ]
  then
    target_file_extension=''
  else
    target_file_extension=.${target_file_extension}
  fi
  translated_file=`echo ${target_file} | sed "s|\.[^.]*$||"`${insertional_extension_language_code}${target_file_extension}
}

get_alternative(){
  cout 'get_alternative'
  ${base_directory}/bin/`echo $target_directory | sed "s|^${working_directory}/||" | tr / -`
}

backup_source(){
  if [ -f $target_file ]
  then
    cout "backup the old source ${target_file} --> ${target_file}.old"
    mv $target_file ${target_file}.old
  fi
}

check_source_update(){
  if ! cmp -s $target_file ${target_file}.old
  then
    cout "the source is not updated"
    target_is_not_updated=true
  else
    target_is_not_updated=false
  fi
}

remove_backup(){
  if [ -f ${target_file}.old ]
  then
    check_source_update
    cout "remove the old source file --> ${target_file}.old"
    rm ${target_file}.old
  fi
}

get_source(){
  backup_source
  if [ "$target_scheme" = 'null' ]
  then
    cout "null scheme"
    ln ${target_file}.old $target_file
  elif [ "$target_scheme" = 'alternative' ]
  then
    get_alternative
  else
    cout "try get use $get_command"
    $get_command $get_options "${s}"
  fi
  target_charset=(`nkf --guess $target_file`)
  cout "target charset is $target_charset"
  remove_backup
}

generate_po(){
  cout "generate_po --> $po_file"
  $po_new_command -f $po_format -m $target_file -M $target_charset -p $po_file --msgid-bugs-address "$po_msgid_bugs_address" --copyright-holder "$po_copyright_holder" --package-name "$po_package_name" --package-version "$po_package_version"
}

update_po(){
  if $target_is_not_updated
  then
    cout 'update_po is passed'
  else
    cout "update_po --> $po_file"
    $po_update_command -f $po_format -m $ascii_file -M $target_charset -p $po_file --msgid-bugs-address "$po_msgid_bugs_address" --copyright-holder "$po_copyright_holder" --package-name "$po_package_name" --package-version "$po_package_version"
  fi
}

translate(){
  cout "translate --> $translated_file"
  $po_translate_command -f $po_format -m $ascii_file -M $target_charset -p $po_file -l $translated_file -k $po_translate_keep_ratio
}

create_target_directory(){
  cout "create_target_directory --> $target_directory"
  mkdir -p $target_directory
}

push_directory(){
  cout "push_directory --> $1"
  pushd $1
}

pop_directory(){
  cout 'pop_directory'
  popd
}

update(){
  cout 'update'

  for s in $sources
  do
    cout "current target is ${s}"

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
  cout 'git_init'
  git init
}

git_pull(){
  cout 'git_pull'
  git pull
}

git_add_and_commit(){
  cout 'git_add_and_commit'
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
  #date=`date --rfc-2822`

  # http source sample
  #sources="$sources http://uncyclopedia.wikia.com/wiki/Main_Page"
  # null source sample; see also README
  #sources="$sources null://const-static/document.txt"
  # alternative source sample; see also README
  #sources="$sources alternative://alternative/test/hoge.txt"

  #additional_extension_po='.po'
  #insertional_extension_language_code='.ja'

  #get_command='curl'
  #get_options='-O'

  #po_new_command='po4a-gettextize'
  #po_update_command='po4a-updatepo'
  #po_translate_command='po4a-translate'
  #po_format='text'
  #po_master_charset='utf-8'
  #po_msgid_bugs_address='<ENTER YOUR EMAIL>'
  #po_copyright_holder='<ENTER YOUR NAME>'
  #po_package_name='<ENTER YOUR PACKAGE>'
  #po_package_version=$date
  #po_translate_keep_ratio=0

  #working_directory='working'

  #auto_git=false

  additional_paths="$additional_paths /usr/bin/vendor_perl"

  #base_directory=`pwd`
}
EOD

}

configure_default(){
  date=`date --rfc-2822`
  sources=()

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

  auto_git=false

  additional_paths=()

  base_directory=`pwd`
}

load_configure(){
  cout 'load_configure'
  
  if [ -d etc -a -r etc/auto-po4a.configure ]
  then
    configure_default
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
  cout 'start'
  load_configure
  configure
  if $auto_git && [ ! -d .git ]
  then
    git_init
  elif $auto_git && [ `git config remote.origin.url` ]
  then
    git_pull
  fi
  add_path
  update
  if $auto_git [ -d .git ]
  then
    git_add_and_commit
  fi
  cout 'to exit'
}

main


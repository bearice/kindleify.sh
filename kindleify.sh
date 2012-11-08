#!/bin/sh
function show_help(){
    echo "Usage: $0 [-v] [-h] [-o output_dir] input_file ... "
}

function check_env(){
    which convert > /dev/null
    if [ $? != 0 ]; then
        echo ImageMagick is not installed.
        exit 1
    fi

    which xxd > /dev/null
    if [ $? != 0 ]; then
        echo xxd is not available.
        exit 1
    fi
}

function fullpath(){
    echo $(cd $(dirname $1); pwd)/$(basename $1)
}

function make_workdir(){
    if uname | grep -q Darwin; then
        mktemp -d -t kindleify;
    else
        mktemp -d -t kindleify.XXXXXX;
    fi
}

function clean_name(){
    echo $(basename $1) | sed -e's/\.rar$//' -e 's/\.zip$//'
}

function get_magic(){
    xxd -l4 -ps $1
}

function unpack_files(){
    if [ ! -f $1 ] ; then echo File not found: $1 ; return 1 ; fi
    echo Unpacking file $1 to $2
    mkdir -p $2
    
    MAGIC=$(get_magic $1)
    case $MAGIC in
        504b0304)
            #PK..
            unzip -d $2 $1 > $VERBOSE
            ;;
        52617221)
            #Rar!
            unrar x $1 $2 > $VERBOSE
            ;;
    esac
    cd $2
    find . -name '*.png' -or -name '*.jpg' -or -name '*.jpeg' -or -name '*.gif' | sed -e 's/^.\///' > $3
    echo Total $(wc -l $3) file\(s\)
}

function pack_files(){
    echo $1
    cd $2
    zip -@ $1 < $3  > $VERBOSE
}

function do_convert(){
    echo Converting $3
    mkdir -p `dirname $2/$3`
    convert $1/$3 -resize 600x800 -colorspace gray $2/$3
}

function clean_up(){
    echo Removing temporary files : $WDIR
    rm -rf $WDIR
}

check_env
VERBOSE=/dev/null

if [ "x$1" = x ]; then show_help; exit 1; fi

while [ "$(echo $1 | cut -c1)" = "-" ]
do
    case $1 in
        -h|--help)
            show_help
            ;;
        -v)
            VERBOSE=/dev/stdout
            ;;
        -o)
            shift
            OUT=$1
            if [ ! -d $OUT ]; then
                echo Could not open dir: $OUT;
                exit 1;
            fi
            ;;
        *)
            echo "Syntax Error: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

while [ "x$1" != x ]
do
    SRC=$(fullpath $1)
    if [ "x$OUT" = "x" ]; then 
        DST=$(dirname $SRC); 
    fi
    DST=$DST/$(clean_name $1).kindle.zip

    WDIR=$(make_workdir)
    ODIR=$WDIR/o
    DDIR=$WDIR/d

    FLST=$WDIR/filelist
    unpack_files $SRC $ODIR $FLST

    cat $FLST | while read; do
        do_convert $ODIR $DDIR $REPLY;
    done

    pack_files $DST $DDIR $FLST

    clean_up
    shift
done

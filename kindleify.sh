#!/bin/sh
PPWD=$(pwd)

function show_help(){
    echo "Usage: $0 [-v] [-h] [-o output_dir] input_file ... "
    echo "Options:"
    echo "    -h     show help"
    echo "    -v     verbose mode"
    echo "    -j     set JPEG output (default is png)"
    echo "    -o dir set output dir (default to same path of source file)"
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
    echo $(basename $1) | sed -e 's/\.[^.]\{1,\}$//'
}

function get_magic(){
    xxd -l4 -ps $1
}

function unpack_files(){
    if [ ! -f "$1" ] ; then echo File not found: $1 ; exit 1 ; fi
    echo Unpacking file $1 to $2
    mkdir -p "$2"
    
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
    cd $PPWD
    echo Total $(wc -l $3 | awk '{print $1}') file\(s\)
}

function pack_files(){
    echo Packing to $1
    cd $2
    find . | sed -e 's/^.\///' | zip -9 -@ $1  > $VERBOSE
    cd $PPWD
}

function do_convert(){
    P=$(dirname "$2/$3")
    mkdir -p "$P"
    SFN=$3
    DFN=$3.$OFMT
    echo "Converting $SFN => $DFN"
    convert "$1/$SFN" -resize 600x800 -colorspace gray "$2/$DFN"
}

function clean_up(){
    echo Removing temporary files : $WDIR
    rm -rf $WDIR
}

check_env
VERBOSE=/dev/null
OFMT=png

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
        -j)
            OFMT=jpg
            ;;
        -o)
            shift
            if [ ! -d $1 ]; then
                echo Could not open dir: $1;
                exit 1;
            fi
            OUT=$(cd $1; pwd)
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
        OUT=$(dirname $SRC); 
    fi
    DST=$OUT/$(clean_name $1).kindle.zip

    WDIR=$(make_workdir)
    ODIR=$WDIR/o
    DDIR=$WDIR/d

    FLST=$WDIR/filelist
    unpack_files $SRC $ODIR $FLST

    cat $FLST | while read; do
        do_convert $ODIR $DDIR "$REPLY";
    done

    pack_files $DST $DDIR $FLST

    clean_up
    shift
done

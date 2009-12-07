#!/bin/sh
# Copyright (c) 2009 Serge "ftrvxmtrx" Ziryukin
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Dependencies:
#          shntool, cuetools
# SPLIT:   flac, wavpack, mac
# CONVERT: flac, faac, libmp4v2, id3lib, lame, vorbis-tools
# ART:     ImageMagick
# CHARSET: iconv

CONFIG="${HOME}/.split2flac"
TMPCUE="${HOME}/.split2flac_sheet.cue"
TMPPIC="${HOME}/.split2flac_cover.jpg"

NOSUBDIRS=0
NORENAME=0
NOPIC=0
REMOVE=0
NOCOLORS=0
PIC_SIZE="192x192"
FORMAT="${0##*split2}"
FORMAT="${FORMAT%.sh}"
DIR="."

# load settings
eval $(cat "${CONFIG}" 2>/dev/null)
DRY=0
SAVE=0
unset PIC INPATH CUE CHARSET
FORCE=0

HELP="\${cG}split2flac splits one big \${cU}APE/FLAC/WV\$cZ\$cG file to \${cU}FLAC/M4A/MP3/OGG_VORBIS\$cZ\$cG tracks with tagging and renaming.

Usage: \${cZ}split2\${FORMAT}.sh [\${cU}OPTIONS\$cZ] \${cU}FILE\$cZ [\${cU}OPTIONS\$cZ]\$cZ
       \${cZ}split2\${FORMAT}.sh [\${cU}OPTIONS\$cZ] \${cU}DIR\$cZ  [\${cU}OPTIONS\$cZ]\$cZ
         \$cG-p\$cZ                    - dry run
         \$cG-o \${cU}DIRECTORY\$cZ        \$cR*\$cZ - set output directory (current is \$cP\${DIR}\$cZ)
         \$cG-cue \${cU}FILE\$cZ             - use file as a cue sheet (does not work with \${cU}DIR\$cZ)
         \$cG-cuecharset \${cU}CHARSET\$cZ   - convert cue sheet from CHARSET to UTF-8 (no conversion by default)
         \$cG-f \${cU}FORMAT\$cZ             - use specified output format \$cP(current is \${FORMAT})\$cZ
         \$cG-c \${cU}FILE\$cZ             \$cR*\$cZ - use file as a cover image (does not work with \${cU}DIR\$cZ)
         \$cG-nc                 \${cR}*\$cZ - do not set any cover images
         \$cG-cs \${cU}WxH\$cZ             \$cR*\$cZ - set cover image size \$cP(current is \${PIC_SIZE})\$cZ
         \$cG-d                  \$cR*\$cZ - create artist/album subdirs (default)
         \$cG-nd                 \$cR*\$cZ - do not create any subdirs
         \$cG-r                  \$cR*\$cZ - rename tracks to include title (default)
         \$cG-nr                 \$cR*\$cZ - do not rename tracks (numbers only, e.g. '01.\${FORMAT}')
         \$cG-D                  \$cR*\$cZ - delete original file
         \$cG-nD                 \$cR*\$cZ - do not remove the original (default)
         \$cG-F\$cZ                    - force deletion without asking
         \$cG-colors\$cZ             \$cR*\$cZ - colorized output (default)
         \$cG-nocolors\$cZ           \$cR*\$cZ - turn off colors
         \$cG-s\$cZ                    - save configuration to \$cP\"\${CONFIG}\"\$cZ
         \$cG-h\$cZ                    - print this message

\$cR*\$cZ - option affects configuration if \$cP'-s'\$cZ option passed.
\${cP}NOTE: \$cG'-c some_file.jpg -s'$cP only \${cU}allows\$cZ\$cP cover images, it doesn't set a default one.
\${cZ}Supported \$cU\${cG}FORMATs\${cZ}: flac, m4a, mp3, ogg.

It's better to pass \$cP'-p'\$cZ option to see what will happen when actually splitting tracks.
You may want to pass \$cP'-s'\$cZ option for the first run to save default configuration
(output dir, cover image size, etc.) so you won't need to pass a lot of options
every time, just a filename. Script will try to find CUE sheet if it wasn't specified.
It also supports internal CUE sheets (FLAC, APE and WV)."

msg="echo -e"

emsg () {
    $msg "${cR}$1${cZ}"
}

update_colors () {
    if [ "${NOCOLORS}" -eq 0 ]; then
        cR="\033[31m"
        cG="\033[32m"
        cC="\033[35m"
        cP="\033[36m"
        cU="\033[4m"
        cZ="\033[0m"
    else
        unset cR cG cC cP cU cZ
    fi
}

update_colors

# parse arguments
while [ "$1" ]; do
    case "$1" in
        -o)          DIR=$2; shift;;
        -cue)        CUE=$2; shift;;
        -cuecharset) CHARSET=$2; shift;;
        -f)          FORMAT=$2; shift;;
        -c)          NOPIC=0; PIC=$2; shift;;
        -nc)         NOPIC=1;;
        -cs)         PIC_SIZE=$2; shift;;
        -d)          NOSUBDIRS=0;;
        -nd)         NOSUBDIRS=1;;
        -r)          NORENAME=0;;
        -nr)         NORENAME=1;;
        -p)          DRY=1;;
        -D)          REMOVE=1;;
        -nD)         REMOVE=0;;
        -F)          FORCE=1;;
        -colors)     NOCOLORS=0; update_colors;;
        -nocolors)   NOCOLORS=1; update_colors;;
        -s)          SAVE=1;;
        -h|--help|-help) eval "$msg \"${HELP}\""; exit 0;;
        -*) eval "$msg \"${HELP}\""; emsg "\nUnknown option $1"; exit 1;;
        *)
            if [ "${INPATH}" ]; then
                eval "$msg \"${HELP}\""
                emsg "\nUnknown option $1"
                exit 1
            elif [ ! -r "$1" ]; then
                emsg "Unable to read $1"
                exit 1
            else
                INPATH="$1"
            fi;;
    esac
    shift
done

# save configuration if needed
if [ ${SAVE} -eq 1 ]; then
    echo "DIR=\"${DIR}\"" > "${CONFIG}"
    echo "NOSUBDIRS=${NOSUBDIRS}" >> "${CONFIG}"
    echo "NORENAME=${NORENAME}" >> "${CONFIG}"
    echo "NOPIC=${NOPIC}" >> "${CONFIG}"
    echo "REMOVE=${REMOVE}" >> "${CONFIG}"
    echo "PIC_SIZE=${PIC_SIZE}" >> "${CONFIG}"
    echo "NOCOLORS=${NOCOLORS}" >> "${CONFIG}"
    $msg "${cP}Configuration saved$cZ"
fi

METAFLAC="metaflac --no-utf8-convert"
VORBISCOMMENT="vorbiscomment -R -a"
ID3TAG="id3tag -2"
MP4TAGS="mp4tags"
GETTAG="cueprint -n 1 -t"
VALIDATE="sed s/[^-[:space:][:alnum:]&_#,.'\"\(\)!?]//g"

# check & print output format
msg_format="${cG}Output format :$cZ"
case ${FORMAT} in
    flac) $msg "$msg_format FLAC";;
    m4a)  $msg "$msg_format M4A";;
    mp3)  $msg "$msg_format MP3";;
    ogg)  $msg "$msg_format OGG VORBIS";;
    *)    emsg "Unknown output format \"${FORMAT}\""; exit 1;;
esac

$msg "${cG}Output dir    :$cZ ${DIR:?Output directory was not set}"

# splits a file
split_file () {
    FILE="$1"

    if [ ! -r "${FILE}" ]; then
        emsg "Can not read the file"
        return 1
    fi

    # search for a cue sheet if not specified
    if [ -z "${CUE}" ]; then
        CUE="${FILE}.cue"
        if [ ! -r "${CUE}" ]; then
            CUE="${FILE%.*}.cue"
            if [ ! -r "${CUE}" ]; then
                # try to extract internal one
                CUESHEET=$(${METAFLAC} --show-tag=CUESHEET "${FILE}" 2>/dev/null | sed 's/^cuesheet=//;s/^CUESHEET=//')

                # try WV internal cue sheet
                if [ -z "${CUESHEET}" ]; then
                    CUESHEET=$(wvunpack -q -c "${FILE}" 2>/dev/null)
                fi

                # try APE internal cue sheet (omfg!)
                if [ -z "${CHESHEET}" ]; then
                    APETAGEX=$(tail -c 32 "$1" | cut -b 1-8 2>/dev/null)
                    if [ "${APETAGEX}" = "APETAGEX" ]; then
                        LENGTH=$(tail -c 32 "$1" | cut -b 13-16 | od -t u4 | awk '{printf $2}') 2>/dev/null
                        tail -c ${LENGTH} "$1" | grep -a CUESHEET >/dev/null 2>&1
                        if [ $? -eq 0 ]; then
                            CUESHEET=$(tail -c ${LENGTH} "$1" | sed 's/.*CUESHEET.//g' 2>/dev/null)
                            if [ $? -ne 0 ]; then
                                CUESHEET=""
                            fi
                        fi
                    fi
                fi

                if [ "${CUESHEET}" ]; then
                    $msg "${cP}Found internal cue sheet$cZ"
                    CUE="${TMPCUE}"
                    echo "${CUESHEET}" > "${CUE}"

                    if [ $? -ne 0 ]; then
                        emsg "Unable to save internal cue sheet"
                        return 1
                    fi
                else
                    unset CUE
                fi
            fi
        fi
    fi

    # print cue sheet filename
    if [ -z "${CUE}" ]; then
        emsg "No cue sheet"
        return 1
    fi

    if [ "${CHARSET}" ]; then
        $msg "${cG}Cue charset : $cP${CHARSET} -> utf-8$cZ"
        CUESHEET=$(iconv -c -f "${CHARSET}" -t utf-8 "${CUE}" 2>/dev/null)
        if [ $? -ne 0 ]; then
            emsg "Unable to convert cue sheet from ${CHARSET} to utf-8"
            return 1
        fi
        CUE="${TMPCUE}"
        echo "${CUESHEET}" > "${CUE}"

        if [ $? -ne 0 ]; then
            emsg "Unable to save converted cue sheet"
            return 1
        fi
    fi

    # search for a front cover image
    if [ ${NOPIC} -eq 1 ]; then
        unset PIC
    elif [ -z "${PIC}" ]; then
        # try common names 
        SDIR=$(dirname "${FILE}")

        for i in cover.jpg front_cover.jpg folder.jpg; do
            if [ -r "${SDIR}/$i" ]; then
                PIC="${SDIR}/$i"
                break
            fi
        done

        # try to extract internal one
        if [ -z "${PIC}" ]; then
            ${METAFLAC} --export-picture-to="${TMPPIC}" "${FILE}" 2>/dev/null
            if [ $? -ne 0 ]; then
                unset PIC
            else
                PIC="${TMPPIC}"
            fi
        fi
    fi

    $msg "${cG}Cue sheet     :$cZ ${CUE}"
    $msg "${cG}Cover image   :$cZ ${PIC:-not set}"

    # file removal warning
    if [ ${REMOVE} -eq 1 ]; then
        msg_removal="\n${cR}Also remove original"
        if [ ${FORCE} -eq 1 ]; then
            $msg "$msg_removal (WITHOUT ASKING)$cZ"
        else
            $msg "$msg_removal if user says 'y'$cZ"
        fi
    fi

    # get common tags
    TAG_ARTIST=$(${GETTAG} %P "${CUE}" 2>/dev/null)
    TAG_ALBUM=$(${GETTAG} %T "${CUE}" 2>/dev/null)
    TRACKS_NUM=$(${GETTAG} %N "${CUE}" 2>/dev/null)

    YEAR=$(awk '{ if (/REM[ \t]+DATE/) { printf "%i", $3; exit } }' < "${CUE}")
    YEAR=$(echo ${YEAR} | tr -d -C '[:digit:]')

    unset TAG_DATE

    if [ "${YEAR}" ]; then
        if [ ${YEAR} -ne 0 ]; then
            TAG_DATE="${YEAR}"
        fi
    fi

    $msg "\n${cG}Artist :$cZ ${TAG_ARTIST}"
    $msg "${cG}Album  :$cZ ${TAG_ALBUM}"
    if [ "${TAG_DATE}" ]; then
        $msg "${cG}Year   :$cZ ${TAG_DATE}"
    fi
    $msg "${cG}Tracks :$cZ ${TRACKS_NUM}\n"

    # prepare output directory
    OUT="${DIR}"

    if [ ${NOSUBDIRS} -ne 1 ]; then
        DIR_ARTIST=$(echo ${TAG_ARTIST} | ${VALIDATE})
        DIR_ALBUM=$(echo ${TAG_ALBUM} | ${VALIDATE})

        if [ "${TAG_DATE}" ]; then
            DIR_ALBUM="${TAG_DATE} - ${DIR_ALBUM}"
        fi

        if [ ${DRY} -ne 1 ]; then
            mkdir -p "${OUT}/${DIR_ARTIST}"
        fi
        OUT="${OUT}/${DIR_ARTIST}/${DIR_ALBUM}"
    fi

    $msg "${cP}Saving tracks to $cZ\"${OUT}\""

    if [ ${DRY} -ne 1 ]; then
        # create output dir
        mkdir "${OUT}"

        if [ $? -ne 0 -a ${NOSUBDIRS} -ne 1 ]; then
            emsg "Failed to create output directory (already splitted?)"
            return 1
        fi

        case ${FORMAT} in
            flac) ENC="flac flac -0 - -o %f";;
            m4a)  ENC="cust ext=m4a faac -q 500 -o %f -";;
            mp3)  ENC="cust ext=mp3 lame --preset extreme - %f";;
            ogg)  ENC="cust ext=ogg oggenc -q 10 - -o %f";;
            *)    emsg "Unknown output format ${FORMAT}"; exit 1;;
        esac

        # split to tracks
        cuebreakpoints "${CUE}" 2>/dev/null | \
            shnsplit -O never -o "${ENC}" -d "${OUT}" -t "%n" "${FILE}"
        if [ $? -ne 0 ]; then
            emsg "Failed to split"
            return 1
        fi

        # prepare cover image
        if [ "${PIC}" ]; then
            convert "${PIC}" -resize "${PIC_SIZE}" "${TMPPIC}"
            if [ $? -eq 0 ]; then
                PIC="${TMPPIC}"
            else
                $msg "${cR}Failed to convert cover image$cZ"
                unset PIC
            fi
        fi
    fi

    # set tags and rename
    $msg "\n${cP}Setting tags$cZ"

    i=1
    while [ $i -le ${TRACKS_NUM} ]; do
        TAG_TITLE=$(cueprint -n $i -t %t "${CUE}" 2>/dev/null)
        FILE_TRACK="$(printf %02i $i)"
        FILE_TITLE=$(echo ${TAG_TITLE} | ${VALIDATE})
        f="${OUT}/${FILE_TRACK}.${FORMAT}"

        $msg "$i: $cG${TAG_TITLE}$cZ"

        if [ ${NORENAME} -ne 1 ]; then
            FINAL="${OUT}/${FILE_TRACK} - ${FILE_TITLE}.${FORMAT}"
            if [ ${DRY} -ne 1 ]; then
                mv "$f" "${FINAL}"
                if [ $? -ne 0 ]; then
                    emsg "Failed to rename track file"
                    return 1
                fi
            fi
        else
            FINAL="$f"
        fi

        if [ ${DRY} -ne 1 ]; then
            case ${FORMAT} in
                flac)
                    ${METAFLAC} --remove-all-tags \
                        --set-tag="ARTIST=${TAG_ARTIST}" \
                        --set-tag="ALBUM=${TAG_ALBUM}" \
                        --set-tag="TITLE=${TAG_TITLE}" \
                        --set-tag="TRACKNUMBER=$i" \
                        "${FINAL}" >/dev/null
                    RES=$?

                    if [ "${TAG_DATE}" ]; then
                        ${METAFLAC} --set-tag="DATE=${TAG_DATE}" "${FINAL}" >/dev/null
                        RES=$RES$?
                    fi

                    if [ "${PIC}" ]; then
                        ${METAFLAC} --import-picture-from="${PIC}" "${FINAL}" >/dev/null
                        RES=$RES$?
                    fi
                    ;;

                mp3)
                    ${ID3TAG} "-a${TAG_ARTIST}" \
                        "-A${TAG_ALBUM}" \
                        "-s${TAG_TITLE}" \
                        "-t$i" \
                        "-T${TRACKS_NUM}" \
                        "${FINAL}" >/dev/null
                    RES=$?

                    if [ "${TAG_DATE}" ]; then
                        ${ID3TAG} -y"${TAG_DATE}" "${FINAL}" >/dev/null
                        RES=$RES$?
                    fi
                    ;;

                ogg)
                    ${VORBISCOMMENT} "${FINAL}" \
                        -t "ARTIST=${TAG_ARTIST}" \
                        -t "ALBUM=${TAG_ALBUM}" \
                        -t "TITLE=${TAG_TITLE}" \
                        -t "TRACKNUMBER=$i" >/dev/null
                    RES=$?

                    if [ "${TAG_DATE}" ]; then
                        ${VORBISCOMMENT} "${FINAL}" -t "DATE=${TAG_DATE}" >/dev/null
                        RES=$RES$?
                    fi
                    ;;

                m4a)
                    ${MP4TAGS} "${FINAL}" \
                        -a "${TAG_ARTIST}" \
                        -A "${TAG_ALBUM}" \
                        -s "${TAG_TITLE}" \
                        -t "$i" \
                        -T "${TRACKS_NUM}" >/dev/null
                    RES=$?

                    if [ "${TAG_DATE}" ]; then
                        ${MP4TAGS} "${FINAL}" -y "${TAG_DATE}" >/dev/null
                        RES=$RES$?
                    fi

                    if [ "${PIC}" ]; then
                        ${MP4TAGS} "${FINAL}" -P "${PIC}" >/dev/null
                        RES=$RES$?
                    fi
                    ;;

                *)
                    emsg "Unknown output format ${FORMAT}"
                    return 1
                    ;;
            esac

            if [ ${RES} -ne 0 ]; then
                emsg "Failed to set tags for track"
                return 1
            fi
        fi

        $msg "   -> ${cP}${FINAL}$cZ"

        i=$(($i + 1))
    done

    rm -f "${TMPPIC}"
    rm -f "${TMPCUE}"

    if [ ${DRY} -ne 1 -a ${REMOVE} -eq 1 ]; then
        YEP="n"

        if [ ${FORCE} -ne 1 ]; then
            echo -n "Are you sure you want to delete original? [y] >"
            read YEP
        fi

        if [ "${YEP}" = "y" -o ${FORCE} -eq 1 ]; then
            rm -f "${FILE}"
        fi
    fi

    return 0
}

split_collection () {
    while read -r FILE; do
        $msg "$cG>> $cC\"${FILE}\"$cZ"
        unset PIC CUE
        split_file "${FILE}"

        if [ ! $? -eq 0 ]; then
            emsg "Failed to split \"${FILE}\""
        fi

        echo
    done
}

# searches for files in a directory and splits them
split_dir () {
    find "$1" -name '*.flac' -o -name '*.ape' -o -name '*.wv' | split_collection
}

if [ -d "${INPATH}" ]; then
    if [ ! -x "${INPATH}" ]; then
        emsg "Directory \"${INPATH}\" is not accessible"
        exit 1
    fi
    $msg "${cG}Input dir     :$cZ ${INPATH}$cZ\n"
    split_dir "${INPATH}"
elif [ "${INPATH}" ]; then
    split_file "${INPATH}"
else
    emsg "No input filename given. Use -h for help."
    exit 1
fi

$msg "\n${cP}Finished$cZ"

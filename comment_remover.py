# written in Python 3.2

import codecs
import re

inputFilePath = 'picowars.p8'
inputLuaFile = codecs.open( inputFilePath, 'r', encoding = 'utf-8-sig' )
inputLuaFileDataList = inputLuaFile.read().split( "\r\n" )
inputLuaFile.close()

outputFilePath = 'picowars_fmt.lua'
outputLuaFile = codecs.open( outputFilePath, 'w', encoding = 'utf-8' )
outputLuaFile.write( codecs.BOM_UTF8.decode( "utf-8" ) )

def create_compile( patterns ):
    compStr = '|'.join( '(?P<%s>%s)' % pair for pair in patterns )
    regexp = re.compile( compStr )

    return regexp

comRegexpPatt = [( "oneLineS", r"--[^\[\]]*?$" ),
                 ( "oneLine", r"--(?!(-|\[|\]))[^\[\]]*?$" ),
                 ( "oneLineBlock", r"(?<!-)(--\[\[.*?\]\])" ),
                 ( "blockS", r"(?<!-)--(?=(\[\[)).*?$" ),
                 ( "blockE", r".*?\]\]" ),
                 ( "offBlockS", r"---+\[\[.*?$" ),
                 ( "offBlockE", r".*?--\]\]" ),
                 ]

comRegexp = create_compile( comRegexpPatt )

comBlockState = False

for i in inputLuaFileDataList:
    res = comRegexp.search( i )
    if res:
        typ = res.lastgroup
        if comBlockState:
            if typ == "blockE":
                comBlockState = False
                i = res.re.sub( "", i )
            else:
                i = ""
        else:
            if typ == "blockS":
                comBlockState = True
                i = res.re.sub( "", i )
            else:
                comBlockState = False
                i = res.re.sub( "", i )
    elif comBlockState:
        i = ""

    if not i == "":
        outputLuaFile.write( "{}\n".format( i ) )

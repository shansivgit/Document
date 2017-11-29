# Hello World program in Python
    
import json
import urllib2

a = ("lnfkjbdfhvdf")
b = ("jvnfdvbdfhvdf")

sep='='
props = {}
with open('sample.properties', "rt") as f:
    for line in f:
        l = line.strip()
        if l and not l.startswith('#'):
            key_value = l.split(sep)
            key = key_value[0].strip()
            value = sep.join(key_value[1:]).strip().strip('"') 
            props[key] = value 
                
print "Printing the Content of Properties file to Json \n" 
print props

data = {
    'a': a,
    'b': b,
    'c': props
}

data_json = json.dumps(data)
print "\n\nFinal Output \n"
print data_json

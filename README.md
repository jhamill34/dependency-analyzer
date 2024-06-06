## Dependency Analyzer 

This repo is used to learn more about the Zig programming language. The idea is to unzip a Java Archive (i.e. JAR file) and 
then parse out the java bytecode. Ultimately, I want to parse out a collection of archives (i.e. a Class Path) and understand
the relationships between how dependencies are used. 

As an example, when using a dependency management system like Gradle or Maven many JAR files are pulled in from a remote 
repository like maven central. These managers will then put all these Jars into a classpath to compile your application. 
As similar classpath is constructed for runtime. Understanding what parts of these dependencies are actually used can be 
useful in possibly splitting out dependencies or determining if a dependency is even needed (i.e. you're only using a single 
class or method that you could maybe write yourself). 

## Learning

- [Zip Format](https://en.wikipedia.org/wiki/ZIP_(file_format))
- [DEFLATE](https://www.rfc-editor.org/rfc/rfc1951)
- [Java Class Format](https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-4.html)

### Zip Format 

A zip file is parsed from the end backwards using offsets (kind of like a linked list in a way). The 
Central Directory lists out the contents of the archive and tells you the offset in the file where 
the binary data is stored. Once we get to that part we then have the file name and then the binary data. 

### DEFLATE 

The deflate algorithm is what gzip uses. It compresses data using a combindation of LZ77 and Huffman Encoding. 

### Java Class Format 

The binary of the class file is decoded from top to bottom. We get the class, fields, and methods all of which 
reference a constants table that includes the names, signatures, etc. of each. For each we get a collection of 
attributes that also need to be decoded that give us special information. For methods in particular, these attributes
include the actual bytecode instructions, a local variable table, a local variable type table, and stack frames that 
we can use to analyze the method. 

We can use the method and field data, to determine when dependencies are actually referenced. The method data also
gives us insight into method complexity, "pureness" of a method / method side effects, etc. 


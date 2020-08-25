all: java

java: bindir
	javac \
  	src/jstoch/*/*.java \
  	src/landusemodel/*.java \
  	-d bin \
  	-cp colt/colt.jar:gson/gson-2.8.6.jar:junit/junit-4.13.jar

bindir:
	mkdir -p bin

clean:
	rm -r bin

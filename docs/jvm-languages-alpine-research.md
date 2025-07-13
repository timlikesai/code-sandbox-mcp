# JVM Languages on Alpine Linux Research

## Executive Summary

Adding JVM-based languages to the Alpine Linux container requires careful consideration of installation methods, size impact, and execution patterns. Of the four major JVM languages examined (Scala, Kotlin, Groovy, Clojure), only Clojure has an official Alpine package. The others require manual installation or building from source.

## Language-Specific Findings

### 1. Clojure
**Installation**: `apk add clojure` (from community repository)
- **Package Size**: 4.3 MiB
- **Installed Size**: 4.8 MiB
- **Dependencies**: java-jdk (OpenJDK 24 JDK)
- **Execution**: Script mode with `clojure` command
- **Special Considerations**: 
  - Only JVM language with official Alpine package
  - Minimal additional overhead beyond JDK
  - REPL and script execution support built-in

### 2. Kotlin
**Installation**: Manual download of compiler
- **Runtime Size**: ~1.5MB (kotlin-stdlib)
- **Compiler Size**: Additional ~10-15MB
- **Execution**: 
  - Compile: `kotlinc script.kt -include-runtime -d output.jar`
  - Run: `java -jar output.jar`
  - Script mode: `kotlin script.kts`
- **Special Considerations**:
  - No official Alpine package
  - Can use SDKMAN! or manual installation
  - Supports script mode (.kts files) for direct execution

### 3. Groovy
**Installation**: Manual download or via Gradle
- **Core Size**: ~3MB (modularized core)
- **Full Size**: ~6-7MB (with all modules)
- **Execution**:
  - Script mode: `groovy script.groovy`
  - Compile and run: Via groovyc
- **Special Considerations**:
  - No official Alpine package
  - Highly modular since v2.5
  - Excellent script support
  - Often bundled with Gradle

### 4. Scala
**Installation**: Manual download with sbt
- **Library Size**: ~8-9MB (scala-library.jar)
- **Optimized Size**: <1MB with ProGuard
- **Execution**:
  - Compile: `scalac Script.scala`
  - Run: `scala Script`
  - Script mode: `scala script.scala` (Scala 3)
- **Special Considerations**:
  - No official Alpine package
  - Largest runtime of the four
  - Requires sbt for practical use
  - Can be significantly optimized

## Installation Approaches

### 1. Minimal Installation (Script Mode Only)
For languages supporting script execution without compilation:
```dockerfile
# Clojure (easiest - has Alpine package)
RUN apk add --no-cache clojure

# Kotlin (manual installation)
RUN wget https://github.com/JetBrains/kotlin/releases/download/v1.9.22/kotlin-compiler-1.9.22.zip && \
    unzip kotlin-compiler-*.zip && \
    rm kotlin-compiler-*.zip && \
    mv kotlinc /opt/ && \
    ln -s /opt/kotlinc/bin/kotlin /usr/local/bin/kotlin && \
    ln -s /opt/kotlinc/bin/kotlinc /usr/local/bin/kotlinc

# Groovy (manual installation)
RUN wget https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips/apache-groovy-binary-4.0.18.zip && \
    unzip apache-groovy-binary-*.zip && \
    rm apache-groovy-binary-*.zip && \
    mv groovy-* /opt/groovy && \
    ln -s /opt/groovy/bin/groovy /usr/local/bin/groovy

# Scala (manual installation with coursier)
RUN wget -q -O coursier https://git.io/coursier-cli && \
    chmod +x coursier && \
    ./coursier setup -y && \
    rm coursier
```

### 2. Using SDKMAN! (Not recommended for containers)
While SDKMAN! can install all four languages, it's not ideal for Docker containers due to:
- Interactive shell requirements
- Additional overhead
- Dynamic downloading at runtime

### 3. Multi-stage Build Approach
Best practice for production containers:
```dockerfile
# Build stage with full toolchain
FROM openjdk:17-alpine AS builder
# Install compilers and build tools
# Compile application

# Runtime stage with minimal dependencies
FROM openjdk:17-alpine
# Copy only compiled artifacts and runtime libraries
```

## Size Impact Analysis

### Base Requirements
- OpenJDK 17 Alpine: ~200MB
- OpenJDK 21 Alpine: ~250MB

### Additional Language Overhead
1. **Clojure**: +4.8MB (minimal)
2. **Kotlin**: +15-20MB (compiler + stdlib)
3. **Groovy**: +3-7MB (depending on modules)
4. **Scala**: +10-15MB (can be optimized to <2MB)

### Total Container Size Estimates
Assuming OpenJDK 17 base:
- Clojure: ~205MB
- Kotlin: ~220MB
- Groovy: ~207MB
- Scala: ~215MB (unoptimized)

## Execution Patterns

### Script Mode (Fastest for Development)
All four languages support script execution:
```bash
clojure script.clj
kotlin script.kts
groovy script.groovy
scala script.scala  # Scala 3+
```

### Compiled Mode (Better for Production)
```bash
# Kotlin
kotlinc app.kt -include-runtime -d app.jar
java -jar app.jar

# Groovy
groovyc App.groovy
java -cp .:$GROOVY_HOME/lib/* App

# Scala
scalac App.scala
scala App
```

## Recommendations

### For Minimal Size Impact
1. **Use Clojure** - Official Alpine package, smallest overhead
2. **Share JDK installation** - All languages use the same JDK
3. **Use script mode** - Avoid compilation overhead for simple scripts
4. **Optimize with native-image** - GraalVM can create tiny executables

### For Production Use
1. **Multi-stage builds** - Compile in builder, run in minimal image
2. **Use jlink** - Create custom JRE with only needed modules
3. **Consider Alpaquita Linux** - Alpine-based, optimized for JVM
4. **Profile and optimize** - Remove unused dependencies

### Implementation Priority
1. **Clojure** - Easy win with Alpine package
2. **Kotlin** - Popular, good script support, reasonable size
3. **Groovy** - Good for Gradle users, excellent scripting
4. **Scala** - Consider only if specifically requested due to size

## Alpine-Specific Considerations

### musl libc Compatibility
- Modern OpenJDK versions (11+) support musl
- Use Alpine-specific JDK builds (Liberica, Azul Zulu)
- Test thoroughly for native library dependencies

### Package Management
- Enable community repository for Clojure
- Consider creating custom APK packages for other languages
- Use reproducible builds with locked versions

### Security
- Run as non-root user (already implemented)
- Minimize attack surface by installing only needed components
- Regular updates for security patches

## Conclusion

Adding JVM language support to the Alpine container is feasible with minimal impact:
- **Clojure** can be added immediately with ~5MB overhead
- **Kotlin** and **Groovy** require manual installation but add <20MB each
- **Scala** is the heaviest but can be optimized significantly
- All languages can share the same JDK installation
- Script mode execution provides the best balance of functionality and size
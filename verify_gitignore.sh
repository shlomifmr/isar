#!/bin/bash
# Quick verification script to check if built artifacts are ignored

echo "Checking if built artifacts are ignored by git..."
echo ""

# Check Android .so files
echo "=== Android .so files ==="
for abi in arm64-v8a armeabi-v7a x86_64 x86; do
  file="packages/isar_flutter_libs/android/src/main/jniLibs/$abi/libisar.so"
  if [ -f "$file" ]; then
    if git check-ignore -q "$file" 2>/dev/null; then
      echo "❌ IGNORED: $file"
    else
      echo "✅ TRACKED: $file"
    fi
  else
    echo "⚠️  NOT FOUND: $file"
  fi
done

echo ""
echo "=== iOS xcframework ==="
file="packages/isar_flutter_libs/ios/isar.xcframework"
if [ -d "$file" ]; then
  if git check-ignore -q "$file" 2>/dev/null; then
    echo "❌ IGNORED: $file"
  else
    echo "✅ TRACKED: $file (directory)"
  fi

  # Check Info.plist
  test_file="$file/Info.plist"
  if [ -f "$test_file" ]; then
    if git check-ignore -q "$test_file" 2>/dev/null; then
      echo "❌ IGNORED: $test_file"
    else
      echo "✅ TRACKED: $test_file"
    fi
  fi

  # Check .a files
  for arch_dir in "$file"/ios-*; do
    if [ -d "$arch_dir" ]; then
      a_file="$arch_dir/libisar.a"
      if [ -f "$a_file" ]; then
        if git check-ignore -q "$a_file" 2>/dev/null; then
          echo "❌ IGNORED: $a_file"
        else
          echo "✅ TRACKED: $a_file"
        fi
      fi
    fi
  done
else
  echo "⚠️  NOT FOUND: $file"
fi

echo ""
echo "Done! Run this script to verify your built artifacts are tracked."
echo "Usage: bash verify_gitignore.sh"


#!/usr/bin/env python3
"""
Script to update all Poppins font references to Google Fonts Quicksand
"""
import os
import re
import glob

def update_file(file_path):
    """Update a single file to replace Poppins with Google Fonts Quicksand"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if file already has Google Fonts import
        if 'google_fonts/google_fonts.dart' not in content:
            # Add Google Fonts import after the first import
            import_pattern = r'(import [^\n]+;\n)'
            imports = re.findall(import_pattern, content)
            if imports:
                # Insert after the first import
                first_import_end = content.find(imports[0]) + len(imports[0])
                content = (content[:first_import_end] + 
                          "import 'package:google_fonts/google_fonts.dart';\n" + 
                          content[first_import_end:])
        
        # Replace fontFamily: 'Poppins' with fontWeight: FontWeight.w400
        content = re.sub(r"fontFamily:\s*'Poppins'", 'fontWeight: FontWeight.w400', content)
        
        # Replace TextStyle( with GoogleFonts.quicksand(
        content = re.sub(r'TextStyle\(', 'GoogleFonts.quicksand(', content)
        
        # Write back to file
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"Updated: {file_path}")
        return True
    except Exception as e:
        print(f"Error updating {file_path}: {e}")
        return False

def main():
    """Main function to update all Dart files"""
    # Find all Dart files in lib directory
    dart_files = glob.glob('lib/**/*.dart', recursive=True)
    
    updated_count = 0
    for file_path in dart_files:
        if update_file(file_path):
            updated_count += 1
    
    print(f"\nUpdated {updated_count} files successfully!")

if __name__ == "__main__":
    main()

//
//  SourceEditorCommand.swift
//  XML Formater Extension
//
//  Created by Sylvain Roux on 2018-10-10.
//  Copyright © 2018 Sylvain Roux. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand, XMLParserDelegate {
    var completionHandler: ((Error?) -> Void)?
    var invocation: XCSourceEditorCommandInvocation?
    var formatedXml = ""
    var xmlDeclaration: String?
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.

        self.completionHandler = completionHandler
        self.invocation = invocation
        
        // Trim white spaces outside tags
        var allLines = NSString()
        for lineIndex in 0 ..< self.invocation!.buffer.lines.count {
            let line = self.invocation!.buffer.lines[lineIndex] as! NSString
            let trimmedLine = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            allLines = NSString(format: "%@%@", allLines, trimmedLine)
        }
        
        // Add XML declaration to the formated document
        let regex = try? NSRegularExpression(pattern: "<\\?xml.*\\?>", options: [])
        let string = allLines as String
        let matches = regex?.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
        if matches!.count != 0 {
            let range = matches![0].range(at: 0)
            let startIndex = string.index(string.startIndex, offsetBy: range.location)
            let index = string.index(startIndex, offsetBy: range.length)
            self.xmlDeclaration = String(string[..<index])
        }
        
        let data = allLines.data(using: String.Encoding.utf8.rawValue)!
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        let isXmlValid = xmlParser.parse()
        if !isXmlValid {
            self.invocation!.buffer.lines.add("<!-- Error : Invalid XML document -->")
            self.completionHandler!(nil)
        }
    }
    
    var level: Int = 0
    var currentElementName: String?
    var foundCharacters: String = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        self.formatedXml += "\n"
        for _ in 0..<self.level {
            self.formatedXml += "    "
        }
        self.level += 1
        self.formatedXml += "<\(elementName)"
        for attribute in attributeDict {
            self.formatedXml += " \(attribute.key)=\"\(attribute.value)\""
        }
        self.formatedXml += ">"
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        self.foundCharacters += string
    }
    
    func parser(_ parser: XMLParser, foundComment comment: String) {
        self.formatedXml += "\n"
        for _ in 0..<self.level {
            self.formatedXml += "    "
        }
        self.formatedXml += "<!--\(comment)-->"
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        self.level -= 1
        if self.foundCharacters.count != 0 {
            self.formatedXml += self.foundCharacters
            self.foundCharacters = ""
        }
        else {
            self.formatedXml += "\n"
            for _ in 0..<self.level {
                self.formatedXml += "    "
            }
        }
        self.formatedXml += "</\(elementName)>"
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        self.invocation!.buffer.lines.removeAllObjects()
        var formatedXml = ""
        if self.xmlDeclaration != nil {
            formatedXml = self.xmlDeclaration! + self.formatedXml
        }
        else {
            formatedXml += self.formatedXml.dropFirst()
        }
        self.invocation!.buffer.lines.add(formatedXml)
        self.completionHandler!(nil)
    }
}


//
//  zlibService.swift
//  Stossycord
//
//  Created by Stossy11 on 17/1/2026.
//

import Foundation
import zlib

class zlibService {
    private var stream = z_stream()
    private var isInitialized = false
    
    init() {
        setupResource()
    }
    
    private func setupResource() {
        stream.next_in = nil
        stream.avail_in = 0
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        
        let status = inflateInit2_(&stream, MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        if status == Z_OK {
            isInitialized = true
        } else {
            print("Failed to initialize zlib: \(status)")
        }
    }
    
    func reset() {
        if isInitialized {
            let status = inflateReset(&stream)
            if status != Z_OK {
                print("Failed to reset zlib stream: \(status)")
                inflateEnd(&stream)
                isInitialized = false
                setupResource()
            }
        } else {
            setupResource()
        }
    }
    
    func decompress(_ data: Data) -> Data? {
        guard isInitialized else {
            print("zlib not initialized")
            return nil
        }
        
        var decompressed = Data()
        let bufferSize = 16384
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: ptr.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)
            
            while true {
                stream.next_out = UnsafeMutablePointer<Bytef>(&buffer)
                stream.avail_out = uInt(bufferSize)
                
                let status = inflate(&stream, Z_SYNC_FLUSH)
                
                if status == Z_NEED_DICT || status == Z_DATA_ERROR || status == Z_MEM_ERROR {
                    print("Zlib Error: \(status)")
                    return
                }
                
                let count = bufferSize - Int(stream.avail_out)
                if count > 0 {
                    decompressed.append(buffer, count: count)
                }
                
                if stream.avail_out > 0 {
                    break
                }
            }
        }
        return decompressed
    }
    
    deinit {
        if isInitialized {
            inflateEnd(&stream)
        }
    }
}

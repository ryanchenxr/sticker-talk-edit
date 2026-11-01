import Foundation
import AVFoundation
import CoreImage
import AppKit

@main struct StickerDemo {
    static func main() throws {
        let args=CommandLine.arguments
        func value(_ flag:String)->String? { guard let i=args.firstIndex(of:flag),i+1<args.count else{return nil};return args[i+1] }
        guard let output=value("--output") else {
            print("Usage: sticker-demo --output /absolute/demo.mp4 [--hand-font /absolute/font.ttf] [--rounded-font PostScriptName]");return
        }
        let dest=URL(fileURLWithPath:output)
        guard !FileManager.default.fileExists(atPath:dest.path) else {
            throw NSError(domain:"StickerDemo",code:1,userInfo:[NSLocalizedDescriptionKey:"Output exists; choose a new file."])
        }
        try FileManager.default.createDirectory(at:dest.deletingLastPathComponent(),withIntermediateDirectories:true)
        let kit=try StickerKit(roundedFont:value("--rounded-font") ?? "STYuanti-SC-Bold",handFontFile:value("--hand-font"))
        if value("--hand-font") == nil { print("No handwriting font configured; hand samples use the rounded fallback.") }
        let w=1920,h=1080,fps=30,duration=18.0
        let bounds=CGRect(x:0,y:0,width:w,height:h),cs=CGColorSpace(name:CGColorSpace.sRGB)!
        let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(CGColor(red:0.95,green:0.94,blue:0.90,alpha:1));c.fill(bounds)
        c.setStrokeColor(CGColor(gray:0.45,alpha:0.055));c.setLineWidth(1)
        for x in stride(from:0,through:w,by:54){c.move(to:CGPoint(x:x,y:0));c.addLine(to:CGPoint(x:x,y:h))}
        for y in stride(from:0,through:h,by:54){c.move(to:CGPoint(x:0,y:y));c.addLine(to:CGPoint(x:w,y:y))};c.strokePath()
        let bg=CIImage(cgImage:c.makeImage()!)
        struct Cue {let spec:StickerSpec;let x:Double;let y:Double;let start:Double;let end:Double}
        let cues:[Cue]=[
            Cue(spec:StickerSpec(id:"hero",text:"知识迁移",kind:.hero,size:150),x:960,y:230,start:0,end:5.5),
            Cue(spec:StickerSpec(id:"hand",text:"先拆结构，再做表达",kind:.hand,size:94),x:960,y:455,start:0.6,end:5.5),
            Cue(spec:StickerSpec(id:"question",text:"怎么做？",size:84,emoji:"🤔"),x:550,y:740,start:1.2,end:5.5),
            Cue(spec:StickerSpec(id:"puzzle",text:"拆出结构",size:84,emoji:"🧩"),x:1370,y:740,start:2.0,end:5.5),
            Cue(spec:StickerSpec(id:"list-head",text:"一步一步，讲清楚",kind:.hand,size:88,emoji:"🎬"),x:960,y:170,start:5.5,end:11.3),
            Cue(spec:StickerSpec(id:"list01",text:"反差开场",kind:.list,size:76,number:"01"),x:960,y:355,start:5.8,end:11.3),
            Cue(spec:StickerSpec(id:"list02",text:"框架预告",kind:.list,size:76,number:"02"),x:960,y:515,start:6.55,end:11.3),
            Cue(spec:StickerSpec(id:"list03",text:"逐点展开",kind:.list,size:76,number:"03"),x:960,y:675,start:7.3,end:11.3),
            Cue(spec:StickerSpec(id:"list04",text:"升华总结",kind:.list,size:76,number:"04"),x:960,y:835,start:8.05,end:11.3),
            Cue(spec:StickerSpec(id:"number",text:"01",kind:.hero,size:260),x:460,y:400,start:11.3,end:18),
            Cue(spec:StickerSpec(id:"payoff",text:"更有表达力",kind:.hero,size:122),x:1280,y:330,start:11.8,end:18),
            Cue(spec:StickerSpec(id:"note",text:"让重点被看见",kind:.hand,size:94),x:1280,y:580,start:12.3,end:18),
            Cue(spec:StickerSpec(id:"negative",text:"硬剪",kind:.negative,size:84,emoji:"🫠"),x:540,y:845,start:12.8,end:18),
            Cue(spec:StickerSpec(id:"positive",text:"顺着逻辑剪",size:82,emoji:"✨"),x:1330,y:845,start:13.5,end:18)
        ]
        func frame(_ t:Double)->CIImage {
            var image=bg
            for cue in cues where t>=cue.start && t<cue.end {
                let elapsed=t-cue.start
                let p=min(1,elapsed/0.22),e=1-pow(1-p,3)
                let out=cue.end>=duration ? 1:min(1,(cue.end-t)/0.14)
                let sticker=kit.image(cue.spec,elapsed:elapsed),b=sticker.extent,s=0.96+0.04*e
                let layer=sticker.transformed(by:CGAffineTransform(a:s,b:0,c:0,d:s,tx:cue.x-b.width*s/2,ty:Double(h)-cue.y-b.height*s/2-12*(1-e)))
                    .applyingFilter("CIColorMatrix",parameters:["inputAVector":CIVector(x:0,y:0,z:0,w:min(e,out))])
                image=layer.composited(over:image)
            }
            return image.cropped(to:bounds)
        }
        for t in [2.5,4.8,9.5,10.7,14.8,16.8] {
            let url=dest.deletingLastPathComponent().appendingPathComponent(dest.deletingPathExtension().lastPathComponent+"-proof-\(t).png")
            try kit.context.writePNGRepresentation(of:frame(t),to:url,format:.RGBA8,colorSpace:cs)
        }
        // A time-seeking renderer must be deterministic; no per-frame random texture reseeding.
        let probe=cues[0].spec
        let a=kit.context.pngRepresentation(of:kit.image(probe,elapsed:1.25),format:.RGBA8,colorSpace:cs)!
        let b=kit.context.pngRepresentation(of:kit.image(probe,elapsed:1.25),format:.RGBA8,colorSpace:cs)!
        let changed=kit.context.pngRepresentation(of:kit.image(probe,elapsed:2.25),format:.RGBA8,colorSpace:cs)!
        guard a==b,a != changed else { fatalError("Deterministic animation check failed") }
        print("Same-time rendering stable; different-time foil/motion changes present.")
        let writer=try AVAssetWriter(outputURL:dest,fileType:.mp4)
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:w,AVVideoHeightKey:h,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:12_000_000,AVVideoExpectedSourceFrameRateKey:fps,AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel]])
        let ad=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:w,kCVPixelBufferHeightKey as String:h,kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
        writer.add(input);guard writer.startWriting() else {throw writer.error!};writer.startSession(atSourceTime:.zero)
        for i in 0..<Int(duration*Double(fps)) {
            autoreleasepool {
                while !input.isReadyForMoreMediaData {Thread.sleep(forTimeInterval:0.001)}
                var buf:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,ad.pixelBufferPool!,&buf)
                kit.context.render(frame(Double(i)/Double(fps)),to:buf!,bounds:bounds,colorSpace:cs)
                guard ad.append(buf!,withPresentationTime:CMTime(value:Int64(i),timescale:Int32(fps))) else {fatalError("Video append failed")}
            }
        }
        input.markAsFinished();let sem=DispatchSemaphore(value:0);writer.finishWriting {sem.signal()};sem.wait()
        guard writer.status == .completed else {throw writer.error!}
        print("Wrote 18-second silent style demo: \(dest.path)")
    }
}

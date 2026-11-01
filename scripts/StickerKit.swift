// Native macOS sticker materials rendered with CoreText, Core Image and Metal.
import Foundation
import AppKit
import CoreText
import CoreImage
import Metal

enum StickerKind: String, Codable, Hashable { case hero, plain, hand, list, badge, negative }
struct StickerSpec: Hashable {
    let id: String
    let text: String
    var kind: StickerKind = .plain
    var size: Double = 80
    var emoji: String? = nil
    var number: String? = nil
}

final class StickerKit {
    let context: CIContext
    private let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    private let roundedName: String
    private let handDescriptor: CTFontDescriptor?
    private let kernel: CIColorKernel
    private var cache: [StickerSpec: Geometry] = [:]
    private struct Geometry {
        let bounds: CGRect
        let glyph: CIImage
        let paper: CIImage
        let outline: CIImage
        let decor: CIImage
    }

    init(roundedFont: String = "STYuanti-SC-Bold", handFontFile: String? = nil) throws {
        guard NSFont(name: roundedFont, size: 40) != nil else {
            throw NSError(domain: "StickerKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Rounded font unavailable: \(roundedFont)"])
        }
        roundedName = roundedFont
        if let path = handFontFile {
            let url = URL(fileURLWithPath: path)
            guard let ds = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor], let d = ds.first else {
                throw NSError(domain: "StickerKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot read handwriting font: \(path)"])
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            handDescriptor = d
        } else { handDescriptor = nil }
        guard let gpu = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "StickerKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Metal device unavailable"])
        }
        context = CIContext(mtlDevice: gpu, options: [.cacheIntermediates: false])
        guard let k = CIColorKernel(source: Self.foilSource) else {
            throw NSError(domain: "StickerKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Foil kernel failed to compile"])
        }
        kernel = k
    }

    private static let foilSource = """
    vec3 rainbow(float h, float s, float v) {
        vec3 p = abs(fract(vec3(h) + vec3(0.0, 0.6666667, 0.3333333)) * 6.0 - 3.0);
        return v * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), s);
    }
    float grainHash(vec2 p, float seed) {
        return fract(sin(dot(p, vec2(127.1,311.7)) + seed * 19.19) * 43758.5453);
    }
    vec3 linearRGB(vec3 c) {
        return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));
    }
    kernel vec4 stickerFoil(__sample glyph, __sample paper, __sample outline, __sample decor,
                            vec2 size, float time, float hero, float seed) {
        vec2 p = destCoord();
        vec2 uv = p / size;
        float phase = seed * 6.2831853;
        float tilt = 0.075*sin(time*0.86+phase) + 0.022*sin(time*1.31+phase*0.71);
        float h = 0.78 + uv.x*0.92 + uv.y*0.11 + tilt;
        vec3 prism = rainbow(h,0.48,0.99);
        float band = uv.x + 0.16*uv.y - (0.50+0.60*sin(time*0.73+phase));
        float sheen = exp(-band*band/0.026);
        vec2 cell = floor(p/4.8);
        float n = grainHash(cell,seed);
        vec2 center = vec2(0.22+0.56*grainHash(cell+3.7,seed),0.22+0.56*grainHash(cell+7.9,seed));
        float dotShape = 1.0-smoothstep(0.10,0.23,length(fract(p/4.8)-center));
        float sparkle = step(mix(0.994,0.65,hero),n) * dotShape;
        float glint = 0.35+0.55*pow(0.5+0.5*sin(time*1.35+n*52.0+phase),10.0);
        float grain = (grainHash(floor(p),seed)-0.5)*mix(0.008,0.030,hero);
        vec3 paperColor = mix(vec3(0.986,0.983,0.965),mix(vec3(0.84,0.85,0.87),prism,0.40),hero);
        paperColor = mix(paperColor,prism,mix(0.09,0.12,hero)) + sheen*mix(0.025,0.09,hero) + grain;
        paperColor = mix(paperColor,vec3(1.0),sparkle*(glint+0.17*sheen));
        vec3 blue = vec3(0.19,0.25,0.86);
        vec3 ink = mix(blue+sheen*0.055,rainbow(h+0.025,0.55,0.99),hero);
        ink = mix(ink,vec3(1.0),sparkle*hero*(glint*0.65+0.12*sheen));
        vec3 color = mix(paperColor,blue,outline.r*hero);
        color = mix(color,ink,glyph.r);
        float alpha = paper.r;
        vec4 outColor = vec4(linearRGB(clamp(color,0.0,1.0))*alpha,alpha);
        return decor + outColor*(1.0-decor.a);
    }
    """

    private func bitmap(_ w: Int, _ h: Int) -> CGContext {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
    private func font(_ spec: StickerSpec) -> CTFont {
        if spec.kind == .hand, let d = handDescriptor {
            return CTFontCreateWithFontDescriptor(d, spec.size, nil)
        }
        let latinOnly = !spec.text.isEmpty && spec.text.unicodeScalars.allSatisfy { $0.value < 128 }
        let name = latinOnly && spec.kind == .hero ? "ArialRoundedMTBold" : roundedName
        return CTFontCreateWithName(name as CFString, spec.size, nil)
    }
    private func path(_ text: String, _ font: CTFont) -> CGPath {
        let a = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(a), result = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count), positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(), &glyphs); CTRunGetPositions(run, CFRange(), &positions)
            let f = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
            for i in 0..<count {
                var tr = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                if let p = CTFontCreatePathForGlyph(f, glyphs[i], &tr) { result.addPath(p) }
            }
        }
        return result
    }
    private func alphaMask(_ image: CIImage) -> CIImage {
        let a = CIVector(x: 0,y: 0,z: 0,w: 1), zero = CIVector(x: 0,y: 0,z: 0,w: 0)
        return image.applyingFilter("CIColorMatrix", parameters: ["inputRVector":a,"inputGVector":a,"inputBVector":a,"inputAVector":zero,"inputBiasVector":CIVector(x:0,y:0,z:0,w:1)])
    }
    private func raster(_ image: CIImage, _ bounds: CGRect) -> CIImage {
        CIImage(cgImage: context.createCGImage(image.cropped(to: bounds), from: bounds)!)
    }
    private func geometry(_ s: StickerSpec) -> Geometry {
        if let value = cache[s] { return value }
        let glyphPath = path(s.text,font(s))
        let gb = s.text.isEmpty ? CGRect.zero : glyphPath.boundingBoxOfPath
        let padding = 62.0
        let isRow = s.kind == .list || s.kind == .badge
        let chipH = isRow ? s.size*1.05 : 0
        let chipW = chipH*1.30
        let emojiSize = s.emoji == nil ? 0:s.size*1.22
        let prefix = (isRow ? chipW+15:0) + (s.emoji == nil ? 0:emojiSize+13)
        let contentH = max(gb.height,max(chipH,emojiSize))
        let w = Int(ceil(gb.width+prefix+padding*2)), h = Int(ceil(contentH+padding*2))
        let bounds = CGRect(x:0,y:0,width:w,height:h)
        let gc = bitmap(w,h), dc = bitmap(w,h)
        let tx = padding+prefix-gb.minX, ty = (Double(h)-gb.height)/2-gb.minY
        var tr = CGAffineTransform(translationX:tx,y:ty)
        gc.setFillColor(CGColor(gray:1,alpha:1)); gc.addPath(glyphPath.copy(using:&tr)!)
        if s.kind == .hand { gc.setStrokeColor(CGColor(gray:1,alpha:1));gc.setLineWidth(1.1);gc.setLineJoin(.round);gc.drawPath(using:.fillStroke) }
        else { gc.fillPath() }
        let blue = CGColor(red:0.19,green:0.25,blue:0.86,alpha:1)
        var cursor = padding
        if isRow {
            let y = (Double(h)-chipH)/2
            dc.setFillColor(blue);dc.fillEllipse(in:CGRect(x:cursor,y:y,width:chipW,height:chipH))
            let np = path(s.number ?? "01",CTFontCreateWithName("ArialRoundedMTBold" as CFString,s.size*0.60,nil))
            let nb = np.boundingBoxOfPath
            var nt = CGAffineTransform(translationX:cursor+(chipW-nb.width)/2-nb.minX,y:y+(chipH-nb.height)/2-nb.minY)
            dc.addPath(np.copy(using:&nt)!);dc.setFillColor(CGColor(gray:1,alpha:1));dc.fillPath()
            cursor += chipW+15
        }
        if let emoji = s.emoji {
            let a = NSAttributedString(string:emoji,attributes:[.font:NSFont(name:"AppleColorEmoji",size:emojiSize)!])
            let line = CTLineCreateWithAttributedString(a)
            let eb = CTLineGetImageBounds(line,dc)
            dc.textPosition = CGPoint(x:cursor+(emojiSize-eb.width)/2-eb.minX,y:(Double(h)-eb.height)/2-eb.minY)
            CTLineDraw(line,dc)
        }
        if s.kind == .negative {
            dc.setLineCap(.round);dc.setLineWidth(max(5,s.size*0.075));dc.setStrokeColor(CGColor(red:0.97,green:0.40,blue:0.37,alpha:1))
            dc.move(to:CGPoint(x:padding+prefix-5,y:Double(h)*0.46))
            dc.addLine(to:CGPoint(x:Double(w)-padding+5,y:Double(h)*0.55));dc.strokePath()
        }
        let glyphImage = CIImage(cgImage:gc.makeImage()!), decor = CIImage(cgImage:dc.makeImage()!)
        let support = alphaMask(decor.composited(over:glyphImage))
        let edge = s.kind == .hero ? 26.0:(s.kind == .badge ? 10.0:15.0)
        let paper = support.applyingFilter("CIMorphologyMaximum",parameters:["inputRadius":edge+14])
            .applyingFilter("CIMorphologyMinimum",parameters:["inputRadius":14])
            .applyingFilter("CIGaussianBlur",parameters:["inputRadius":4.2])
            .applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:3,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:3,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:3,w:0),"inputBiasVector":CIVector(x:-1,y:-1,z:-1,w:0)])
            .applyingFilter("CIColorClamp",parameters:["inputMinComponents":CIVector(x:0,y:0,z:0,w:0),"inputMaxComponents":CIVector(x:1,y:1,z:1,w:1)])
        let glyph = alphaMask(glyphImage)
        let outline = glyph.applyingFilter("CIMorphologyMaximum",parameters:["inputRadius":s.kind == .hero ? max(4,s.size*0.025):0])
        let g = Geometry(bounds:bounds,glyph:raster(glyph,bounds),paper:raster(paper,bounds),outline:raster(outline,bounds),decor:decor)
        cache[s] = g;return g
    }
    private func seed(_ id:String) -> Double {
        var h:UInt32 = 2166136261
        for byte in id.utf8 { h = (h ^ UInt32(byte)) &* 16777619 }
        return Double(h%10007)/10007.0
    }

    /// Elapsed seconds relative to this sticker's own cue. Re-seeking is deterministic.
    func image(_ s: StickerSpec, elapsed: Double, motion: Bool = true) -> CIImage {
        let g = geometry(s), t = max(0,elapsed), phase = seed(s.id)
        var surface = kernel.apply(extent:g.bounds,arguments:[g.glyph,g.paper,g.outline,g.decor,
            CIVector(x:g.bounds.width,y:g.bounds.height),t,s.kind == .hero ? 1.0:0.0,phase])!
        if motion {
            let p = phase*Double.pi*2
            let amplitude = s.kind == .badge ? 0.18:(s.kind == .list ? 0.65:1.15)
            let rz = (amplitude*sin(t*1.62+p)+(phase-0.5)*0.7)*Double.pi/180
            let rx = (s.kind == .badge ? 0.5:2.2)*sin(t*1.27+p*0.79)*Double.pi/180
            let ry = (s.kind == .badge ? 0.4:1.8)*sin(t*1.06+p*1.19)*Double.pi/180
            let w=g.bounds.width,h=g.bounds.height,f=max(w,h)*2.6
            func project(_ x:Double,_ y:Double)->CIVector {
                let a=x-w/2,b=y-h/2
                let xx=cos(ry)*a+sin(ry)*sin(rx)*b, yy=cos(rx)*b
                let z = -sin(ry)*a+cos(ry)*sin(rx)*b, k=f/(f+z)
                let bob=(s.kind == .badge ? 0.4:1.8)*sin(t*1.41+p)
                return CIVector(x:w/2+(xx*cos(rz)-yy*sin(rz))*k,y:h/2+(xx*sin(rz)+yy*cos(rz))*k+bob)
            }
            surface=surface.applyingFilter("CIPerspectiveTransform",parameters:["inputTopLeft":project(0,h),"inputTopRight":project(w,h),"inputBottomRight":project(w,0),"inputBottomLeft":project(0,0)])
        }
        let shadow=surface.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:0,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:0,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:0,w:0),"inputAVector":CIVector(x:0,y:0,z:0,w:0.20)])
            .applyingFilter("CIGaussianBlur",parameters:["inputRadius":7])
            .transformed(by:CGAffineTransform(translationX:2+0.6*sin(t+phase),y:-6))
        return surface.composited(over:shadow).cropped(to:g.bounds)
    }
}

// Reference functions that use Bluespec's '*' operator
function Bit#(TAdd#(n,n)) multiply_unsigned( Bit#(n) a, Bit#(n) b );
    UInt#(n) a_uint = unpack(a);
    UInt#(n) b_uint = unpack(b);
    UInt#(TAdd#(n,n)) product_uint = zeroExtend(a_uint) * zeroExtend(b_uint);
    return pack( product_uint );
endfunction

function Bit#(TAdd#(n,n)) multiply_signed( Bit#(n) a, Bit#(n) b );
    Int#(n) a_int = unpack(a);
    Int#(n) b_int = unpack(b);
    Int#(TAdd#(n,n)) product_int = signExtend(a_int) * signExtend(b_int);
    return pack( product_int );
endfunction

function Bit#(2) fa(Bit#(1) a, Bit#(1) b, Bit#(1) c_in);
    let t = a ^ b;
    let s = t ^ c_in; 
    let c_out = (a & b) | (c_in & t); 
    return {c_out,s}; 
endfunction

function Bit#(TAdd#(n,1)) addN(Bit#(n) x, Bit#(n) y, Bit#(1) c0); 
    Bit#(n) s; Bit#(TAdd#(n,1)) c=0; c[0]=c0;
    for(Integer i=0; i<valueOf(n); i=i+1) begin
        let cs=fa(x[i],y[i],c[i]);
        c[i+1]=cs[1];
        s[i]=cs[0];
    end
    return {c[valueOf(n)],s}; 
endfunction


// Multiplication by repeated addition
function Bit#(TAdd#(n,n)) multiply_by_adding( Bit#(n) a, Bit#(n) b );
    // TODO: Implement this function in Exercise 2
    Bit#(n) tp=0;
    Bit#(n) p=0;
    for(Integer i=0; i<valueOf(n); i=i+1) begin
        Bit#(n) m=(a[i]==0)?0:b;
        let s=addN(m,tp,0);
        p[i]=s[0];
        tp=s[valueOf(n):1];
    end
    return {tp,p};
endfunction


function Bit#(n) sra(Bit#(n) a, Integer n);
    Int#(n) a_int = unpack(a);
    return pack(a_int>>n);
endfunction

function Bit#(n) sla(Bit#(n) a, Integer n);
    Int#(n) a_int = unpack(a);
    return pack(a_int<<n);
endfunction


// Multiplier Interface
interface Multiplier#( numeric type n );
    method Bool start_ready();
    method Action start( Bit#(n) a, Bit#(n) b );
    method Bool result_ready();
    method ActionValue#(Bit#(TAdd#(n,n))) result();
endinterface



// Folded multiplier by repeated addition
module mkFoldedMultiplier( Multiplier#(n) );

    // You can use these registers or create your own if you want
    Reg#(Bit#(n)) a <- mkRegU();
    Reg#(Bit#(n)) b <- mkRegU();
    Reg#(Bit#(n)) p <- mkRegU();
    Reg#(Bit#(n)) tp <- mkRegU();
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    rule mulStep(i<fromInteger(valueOf(n)));
        // TODO: Implement this in Exercise 4
        Bit#(n) m=(a[i]==0)?0:b;
        let s=addN(m,tp,0);
        p[i]<=s[0];
        tp<=s[valueOf(n):1];
        i<=i+1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 4
        return i==fromInteger(valueOf(n)+1);
    endmethod

    method Action start( Bit#(n) aIn, Bit#(n) bIn );
        // TODO: Implement this in Exercise 4
        if(i==fromInteger(valueOf(n)+1)) begin
            a<=aIn;
            b<=bIn;
            p<=0;
            tp<=0;
            i<=0;
        end
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 4
        return i==fromInteger(valueOf(n));
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 4
        if(i==fromInteger(valueOf(n))) begin
            i<=i+1;
            return {tp,p};
        end else begin
            return 0;
        end
    endmethod

endmodule



// Booth Multiplier
module mkBoothMultiplier( Multiplier#(n) );

    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    rule mul_step(i<fromInteger(valueOf(n)));
        // TODO: Implement this in Exercise 6
        Bit#(TAdd#(TAdd#(n,n),1)) _p=p;
        let pr=p[1:0];
        if(pr==2'b01) begin _p=p+m_pos; end
        if(pr==2'b10) begin _p=p+m_neg; end
        p<=sra(_p,1);
        i<=i+1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 6
        return i==fromInteger(valueOf(n)+1);
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 6
        if(i==fromInteger(valueOf(n)+1)) begin
            m_pos<={m,0};
            m_neg<={(-m),0};
            p<={0,r,1'b0};
            i<=0;
        end
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 6
        return i==fromInteger(valueOf(n));
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 6
        if(i==fromInteger(valueOf(n))) begin
            i<=i+1;
            return p[2*valueOf(n):1];
        end else begin
            return 0;
        end
    endmethod

endmodule



// Radix-4 Booth Multiplier
module mkBoothMultiplierRadix4( Multiplier#(n) );

    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)/2+1) );

    rule mul_step(i<fromInteger(valueOf(n)/2));
        // TODO: Implement this in Exercise 8
        Bit#(TAdd#(TAdd#(n,n),2)) _p=p;
        let pr=p[2:0];
        if(pr==3'b001) begin _p=p+m_pos; end
        if(pr==3'b010) begin _p=p+m_pos; end
        if(pr==3'b011) begin _p=p+sla(m_pos,1); end
        if(pr==3'b100) begin _p=p+sla(m_neg,1); end
        if(pr==3'b101) begin _p=p+m_neg; end
        if(pr==3'b110) begin _p=p+m_neg; end
        p<=sra(_p,2);
        i<=i+1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 8
        return i==fromInteger(valueOf(n)/2+1);
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 8
        if(i==fromInteger(valueOf(n)/2+1)) begin
            m_pos<={msb(m),m,0};
            m_neg<={msb(-m),(-m),0};
            p<={0,r,1'b0};
            i<=0;
        end
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 6
        return i==fromInteger(valueOf(n)/2);
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 6
        if(i==fromInteger(valueOf(n)/2)) begin
            i<=i+1;
            return p[2*valueOf(n):1];
        end else begin
            return 0;
        end
    endmethod

endmodule


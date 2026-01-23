module courtyard_coverage (
    input clk,
    input rst_n, 
    input start,
    input [31:0] angle_br,
    input [31:0] angle_tr,
    input [31:0] angle_tl,
    input [31:0] angle_bl,
    output reg [31:0] proportion,
    output reg done
);
reg [1:0] state;
reg [6:0] counter;
reg [6:0] covered_count;
reg [3:0] compute_counter;
function automatic [31:0] tan_val;
    input [7:0] deg;
    begin
        if (deg == 45) tan_val = 32'h00010000;
        else tan_val =32'd0;
    end
end
wire [7:0] br_deg = angle_br >> 16;
wire [7:0] tr_deg = angle_tr >> 16;
wire [7:0] tl_deg = angle_tl >> 16;
wire [7:0] bl_deg = angle_bl >> 16;
wire [31:0] tan_br = tan_val(br_deg);
wire [31:0] tan_tr = tan_val(tr_deg);
wire [31:0] tan_tl = tan_val(tl_deg);
wire [31:0] tan_bl = tan_val(bl_deg);
always @(posedge clk) if (!rst_n) begin
    state <= 2'b00;
    counter <=0;
    covered_count <=0;
    compute_counter <=0;
    proportion <=0;
    done <=0;
end else begin
    case(state)
        2'b00: if(start) begin
            state <= 2'b01;
            counter <=0;
            covered_count <=0;
        end
        2'b01: if(counter <64) begin
            int i = counter /8;
            int j = counter %8;
            int x = i * 8192;
            int y = j * 8192;
            int covered =0;
            int rhs = tan_br * (65536 - x);
            if(y <= rhs) covered =1;
            if(covered) covered_count <= covered_count +1;
            counter <= counter +1;
        end else begin
            state <= 2'b10;
            compute_counter <=15;
        end
        2'b10: if(compute_counter ==0) begin
            proportion <= covered_count * 1024;
            state <=2'b11;
        end else begin
            compute_counter <= compute_counter -1;
        end
        2'b11: done <=1;
    endcase
end
endmodule
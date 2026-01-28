module restore_array (
    input clk,
    input rst_n,
    input start,
    input load,
    input [31:0] data_in,
    output reg [31:0] array_out_0,
    output reg [31:0] array_out_1,
    output reg [31:0] array_out_2,
    output reg [31:0] array_out_3,
    output reg [31:0] array_out_4,
    output reg [31:0] array_out_5,
    output reg [31:0] array_out_6,
    output reg [31:0] array_out_7,
    output reg done
);

parameter N = 8;
parameter MEM_SIZE = 64;

reg [31:0] mem [0:63];
reg [5:0] load_counter;

localparam [3:0] IDLE = 4'd0;
localparam [3:0] READ1 = 4'd1;
localparam [3:0] READ2 = 4'd2;
localparam [3:0] READ3 = 4'd3;
localparam [3:0] MULT = 4'd4;
localparam [3:0] DIV = 4'd5;
localparam [3:0] SQRT_START = 4'd6;
localparam [3:0] SQRT_LOOP = 4'd7;
localparam [3:0] SQRT_DONE = 4'd8;
localparam [3:0] FINISH = 4'd9;

reg [3:0] state;
reg [3:0] i;
reg [3:0] j;
reg [3:0] k;
reg [31:0] A;
reg [31:0] B;
reg [31:0] C;
reg [63:0] product;
reg [63:0] quotient;
reg [31:0] sqrt_val;
reg [5:0] bit_index;
reg [5:0] address;

wire [31:0] data_out;
assign data_out = mem[address];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        load_counter <= 6'd0;
        state <= IDLE;
        done <= 1'b0;
        i <= 4'd0;
        j <= 4'd0;
        k <= 4'd0;
        A <= 32'd0;
        B <= 32'd0;
        C <= 32'd0;
        product <= 64'd0;
        quotient <= 64'd0;
        sqrt_val <= 32'd0;
        bit_index <= 6'd0;
        address <= 6'd0;
        array_out_0 <= 32'd0;
        array_out_1 <= 32'd0;
        array_out_2 <= 32'd0;
        array_out_3 <= 32'd0;
        array_out_4 <= 32'd0;
        array_out_5 <= 32'd0;
        array_out_6 <= 32'd0;
        array_out_7 <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    i <= 4'd0;
                    state <= READ1;
                end
            end
            
            READ1: begin
                j <= (i + 4'd1) % N;
                k <= (i + 4'd2) % N;
                address <= i * N + ((i + 4'd1) % N);
                state <= READ2;
            end
            
            READ2: begin
                A <= data_out;
                address <= i * N + ((i + 4'd2) % N);
                state <= READ3;
            end
            
            READ3: begin
                B <= data_out;
                address <= j * N + k;
                state <= MULT;
            end
            
            MULT: begin
                C <= data_out;
                product <= A * B;
                state <= DIV;
            end
            
            DIV: begin
                if (C != 32'd0) begin
                    quotient <= product / C;
                end else begin
                    quotient <= 64'd0;
                end
                state <= SQRT_START;
            end
            
            SQRT_START: begin
                sqrt_val <= 32'd0;
                bit_index <= 6'd31;
                state <= SQRT_LOOP;
            end
            
            SQRT_LOOP: begin
                if (bit_index == 6'd0) begin
                    state <= SQRT_DONE;
                end else begin
                    bit_index <= bit_index - 6'd1;
                end
                if ((sqrt_val + (32'd1 << bit_index)) * (sqrt_val + (32'd1 << bit_index)) <= quotient) begin
                    sqrt_val <= sqrt_val + (32'd1 << bit_index);
                end
            end
            
            SQRT_DONE: begin
                case (i)
                    4'd0: array_out_0 <= sqrt_val;
                    4'd1: array_out_1 <= sqrt_val;
                    4'd2: array_out_2 <= sqrt_val;
                    4'd3: array_out_3 <= sqrt_val;
                    4'd4: array_out_4 <= sqrt_val;
                    4'd5: array_out_5 <= sqrt_val;
                    4'd6: array_out_6 <= sqrt_val;
                    4'd7: array_out_7 <= sqrt_val;
                    default: begin
                        array_out_0 <= sqrt_val;
                        array_out_1 <= sqrt_val;
                        array_out_2 <= sqrt_val;
                        array_out_3 <= sqrt_val;
                        array_out_4 <= sqrt_val;
                        array_out_5 <= sqrt_val;
                        array_out_6 <= sqrt_val;
                        array_out_7 <= sqrt_val;
                    end
                endcase
                i <= i + 4'd1;
                if (i < N - 4'd1) begin
                    state <= READ1;
                end else begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase

        if (load) begin
            if (load_counter < MEM_SIZE) begin
                mem[load_counter] <= data_in;
                load_counter <= load_counter + 6'd1;
            end
        end
    end
end

endmodule
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

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ1 = 3'd1;
    localparam [2:0] READ2 = 3'd2;
    localparam [2:0] READ3 = 3'd3;
    localparam [2:0] MULT = 3'd4;
    localparam [2:0] DIV = 3'd5;
    localparam [2:0] SQRT_START = 3'd6;
    localparam [2:0] SQRT_LOOP = 3'd7;
    localparam [2:0] SQRT_DONE = 3'd8;
    localparam [2:0] DONE_STATE = 3'd9;

    reg [2:0] state;
    reg [2:0] i;
    reg [2:0] j, k;
    reg [31:0] A, B, C;
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
            i <= 3'd0;
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
                        i <= 3'd0;
                        state <= READ1;
                    end
                end
                READ1: begin
                    j <= (i + 1) % 8;
                    k <= (i + 2) % 8;
                    address <= {i, j};
                    state <= READ2;
                end
                READ2: begin
                    A <= data_out;
                    address <= {i, k};
                    state <= READ3;
                end
                READ3: begin
                    B <= data_out;
                    address <= {j, k};
                    state <= MULT;
                end
                MULT: begin
                    C <= data_out;
                    product <= A * B;
                    state <= DIV;
                end
                DIV: begin
                    quotient <= product / C;
                    state <= SQRT_START;
                end
                SQRT_START: begin
                    sqrt_val <= 32'd0;
                    bit_index <= 5'd31;
                    state <= SQRT_LOOP;
                end
                SQRT_LOOP: begin
                    if ((sqrt_val + (32'd1 << bit_index)) * (sqrt_val + (32'd1 << bit_index)) <= quotient) begin
                        sqrt_val <= sqrt_val + (32'd1 << bit_index);
                    end
                    if (bit_index == 5'd0) begin
                        state <= SQRT_DONE;
                    end else begin
                        bit_index <= bit_index - 5'd1;
                    end
                end
                SQRT_DONE: begin
                    case (i)
                        3'd0: array_out_0 <= sqrt_val;
                        3'd1: array_out_1 <= sqrt_val;
                        3'd2: array_out_2 <= sqrt_val;
                        3'd3: array_out_3 <= sqrt_val;
                        3'd4: array_out_4 <= sqrt_val;
                        3'd5: array_out_5 <= sqrt_val;
                        3'd6: array_out_6 <= sqrt_val;
                        3'd7: array_out_7 <= sqrt_val;
                    endcase
                    i <= i + 3'd1;
                    if (i < 3'd7) begin
                        state <= READ1;
                    end else begin
                        state <= DONE_STATE;
                        done <= 1'b1;
                    end
                end
                DONE_STATE: begin
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase

            if (load) begin
                if (load_counter < 6'd64) begin
                    mem[load_counter] <= data_in;
                    load_counter <= load_counter + 6'd1;
                end
            end
        end
    end
endmodule
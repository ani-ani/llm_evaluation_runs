module CaesarCipherDecoder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_string [0:15],
    output reg [7:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] DECODE  = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Declare all registers
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= DECODE;
                    end
                end

                DECODE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Decode all characters in parallel
                    for (i = 0; i < 16; i = i + 1) begin
                        // Subtract 'a' (97), subtract shift (5), mod 26, add 'a'
                        result[i] <= (((input_string[i] - 8'd97) - 8'd5) % 26) + 8'd97;
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
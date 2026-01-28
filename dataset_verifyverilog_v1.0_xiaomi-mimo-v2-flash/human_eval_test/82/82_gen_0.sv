module prime_string_checker (
    input clk,
    input rst_n,
    input start,
    input [3:0] str_len,
    input [7:0] string_data [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg result_reg;
    reg start_prev;
    
    // Prime LUT: bit vector where bit i is 1 if i is prime
    // Bits: 8,7,6,5,4,3,2,1,0 -> 0,1,0,1,0,1,1,0,0
    // LUT[2]=1, LUT[3]=1, LUT[5]=1, LUT[7]=1
    wire [8:0] prime_lut;
    assign prime_lut = 9'b001010110; // bit 2,3,5,7 are prime
    
    // Combinational logic for LUT lookup
    wire prime_check;
    assign prime_check = prime_lut[str_len];
    
    // Edge detection for start signal
    wire start_pulse;
    assign start_pulse = start && !start_prev;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_pulse)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            result_reg <= 1'b0;
            start_prev <= 1'b0;
        end else begin
            start_prev <= start;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start_pulse) begin
                        result_reg <= prime_check;
                    end
                end
                PROCESS: begin
                    // Output result is already set from IDLE
                    done <= 1'b0;
                end
                DONE_STATE: begin
                    result <= result_reg;
                    done <= 1'b1;
                end
                default: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
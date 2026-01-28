module encrypt(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] len,
    output reg [7:0] char_out,
    output reg out_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] READ    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] FINISH  = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] index;
    reg [7:0] latched_char;
    reg [7:0] temp_char;
    
    // Constants
    localparam [7:0] A_LOWER = 8'h61;
    localparam [7:0] Z_LOWER = 8'h7A;
    localparam [7:0] A_UPPER = 8'h41;
    localparam [7:0] Z_UPPER = 8'h5A;
    localparam [7:0] D_LOWER = 8'h64;
    localparam [7:0] D_UPPER = 8'h44;
    localparam [7:0] FOUR = 8'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            latched_char <= 8'd0;
            temp_char <= 8'd0;
            char_out <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            // Default assignments
            out_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        index <= 4'd0;
                        state <= READ;
                    end
                end
                
                READ: begin
                    // Latch character from input
                    latched_char <= char_in;
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    // Perform encryption shift
                    if (latched_char >= A_LOWER && latched_char <= Z_LOWER) begin
                        // Lowercase: a-z
                        if (latched_char <= (Z_LOWER - FOUR)) begin
                            temp_char <= latched_char + FOUR;
                        end else begin
                            // Wrap around: z->d
                            temp_char <= D_LOWER + (latched_char - (Z_LOWER - FOUR));
                        end
                    end else if (latched_char >= A_UPPER && latched_char <= Z_UPPER) begin
                        // Uppercase: A-Z
                        if (latched_char <= (Z_UPPER - FOUR)) begin
                            temp_char <= latched_char + FOUR;
                        end else begin
                            // Wrap around: Z->D
                            temp_char <= D_UPPER + (latched_char - (Z_UPPER - FOUR));
                        end
                    end else begin
                        // Non-alphabetic: pass through
                        temp_char <= latched_char;
                    end
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    // Output encrypted character
                    char_out <= temp_char;
                    out_valid <= 1'b1;
                    index <= index + 4'd1;
                    
                    // Check if all characters processed
                    if (index >= len) begin
                        state <= FINISH;
                    end else begin
                        state <= READ;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
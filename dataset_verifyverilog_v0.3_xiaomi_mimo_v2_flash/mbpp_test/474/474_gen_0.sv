module string_replace (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [7:0] target_char,
    input wire [7:0] replace_char,
    input wire valid_in,
    input wire end_of_string,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] current_char;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: begin
                if (end_of_string)
                    next_state = FINISH;
                else
                    next_state = PROCESS;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            current_char <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_out <= 1'b0;
                    char_out <= 8'd0;
                end
                
                PROCESS: begin
                    if (valid_in) begin
                        current_char <= char_in;
                        // Replace if target character matches
                        if (char_in == target_char) begin
                            char_out <= replace_char;
                        end else begin
                            char_out <= char_in;
                        end
                        valid_out <= 1'b1;
                    end else begin
                        valid_out <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid_out <= 1'b0;
                end
                
                default: begin
                    // Initialize all registers to avoid X values
                    char_out <= 8'd0;
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    current_char <= 8'd0;
                end
            endcase
        end
    end

endmodule
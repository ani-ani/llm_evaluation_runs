module word_len(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire valid_in,
    output reg result,
    output reg done
);

    // Parameters for string processing
    localparam [3:0] MAX_LEN = 4'd15; // Maximum string length (0-15)
    localparam [6:0] CLK_TIMEOUT = 7'd100; // Maximum cycles

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] FINISHED = 2'd2;

    // Internal state
    reg [1:0] state, next_state;
    reg [3:0] len_counter; // Count characters (0-15)
    reg [6:0] cycle_counter;
    reg result_reg;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end
            PROCESSING: begin
                if (!valid_in || len_counter >= MAX_LEN || cycle_counter >= CLK_TIMEOUT) begin
                    next_state = FINISHED;
                end else begin
                    next_state = PROCESSING;
                end
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            len_counter <= 4'd0;
            cycle_counter <= 7'd0;
            result_reg <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        len_counter <= 4'd0;
                        cycle_counter <= 7'd0;
                        result_reg <= 1'b0;
                    end
                end
                
                PROCESSING: begin
                    if (valid_in && len_counter < MAX_LEN) begin
                        // Count non-zero characters
                        if (char_in != 8'h00) begin
                            len_counter <= len_counter + 4'd1;
                        end
                    end
                    
                    cycle_counter <= cycle_counter + 7'd1;
                end
                
                FINISHED: begin
                    // Compute result: true if length is odd and > 0
                    result_reg <= (len_counter[0] == 1'b1) && (len_counter > 4'd0);
                    done <= 1'b1;
                end
                
                default: begin
                    len_counter <= 4'd0;
                    cycle_counter <= 7'd0;
                    result_reg <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Output assignment
    always @(*) begin
        result = result_reg;
    end

endmodule
module happy_string (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_done,
    output reg happy,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READING = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [4:0] char_count;
    reg [4:0] proc_count;
    reg [7:0] window [0:2];
    reg window_valid;
    reg happy_reg;
    reg duplicate_found;
    reg [7:0] temp_char;
    
    // For loop index
    integer i;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            happy <= 1'b0;
            char_count <= 5'd0;
            proc_count <= 5'd0;
            happy_reg <= 1'b0;
            duplicate_found <= 1'b0;
            window_valid <= 1'b0;
            for (i = 0; i < 3; i = i + 1) begin
                window[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    happy <= 1'b0;
                    char_count <= 5'd0;
                    proc_count <= 5'd0;
                    happy_reg <= 1'b0;
                    duplicate_found <= 1'b0;
                    window_valid <= 1'b0;
                    for (i = 0; i < 3; i = i + 1) begin
                        window[i] <= 8'd0;
                    end
                end
                
                READING: begin
                    if (char_valid) begin
                        char_count <= char_count + 5'd1;
                        // Shift window
                        window[2] <= window[1];
                        window[1] <= window[0];
                        window[0] <= char_in;
                        if (char_count >= 5'd2) begin
                            window_valid <= 1'b1;
                        end
                    end
                    if (char_done) begin
                        window_valid <= 1'b1;
                    end
                end
                
                PROCESSING: begin
                    // Check for duplicates in current window
                    if (window_valid && (char_count >= 5'd3)) begin
                        if ((window[0] == window[1]) || 
                            (window[1] == window[2]) || 
                            (window[0] == window[2])) begin
                            duplicate_found <= 1'b1;
                            happy_reg <= 1'b0;
                        end else if (proc_count == 5'd0) begin
                            happy_reg <= 1'b1;
                        end
                        proc_count <= proc_count + 5'd1;
                        
                        // Shift window for next check
                        window[2] <= window[1];
                        window[1] <= window[0];
                        window[0] <= 8'd0;
                        
                        // Reset window_valid after first char
                        if (proc_count >= 5'd0) begin
                            window_valid <= 1'b0;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (char_count >= 5'd3 && !duplicate_found) begin
                        happy <= 1'b1;
                    end else begin
                        happy <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = READING;
                else next_state = IDLE;
            end
            
            READING: begin
                if (char_done) next_state = PROCESSING;
                else next_state = READING;
            end
            
            PROCESSING: begin
                // Continue processing if more chars available
                if (proc_count >= (char_count - 5'd2) && char_count >= 5'd3) begin
                    next_state = DONE_STATE;
                end else if (char_count < 5'd3) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESSING;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
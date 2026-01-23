module Element_Frequency_Counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input valid_in,
    input done_in,
    output reg [7:0] key_out,
    output reg [7:0] count_out,
    output reg valid_out,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CLEAR     = 3'd1;
    localparam [2:0] COUNT     = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] COMPLETE  = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Lookup table (16 entries max)
    reg [7:0] keys [0:15];
    reg [7:0] counts [0:15];
    
    // Counters
    reg [4:0] clear_counter;
    reg [4:0] output_index;
    
    // Temporary variables
    reg found;
    reg [3:0] found_index;
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            key_out <= 8'd0;
            count_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            clear_counter <= 5'd0;
            output_index <= 5'd0;
            found <= 1'b0;
            found_index <= 4'd0;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                keys[i] <= 8'd0;
                counts[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            // Default outputs
            valid_out <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= CLEAR;
                        clear_counter <= 5'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                CLEAR: begin
                    keys[clear_counter] <= 8'd0;
                    counts[clear_counter] <= 8'd0;
                    clear_counter <= clear_counter + 5'd1;
                    
                    if (clear_counter == 5'd16) begin
                        next_state <= COUNT;
                    end else begin
                        next_state <= CLEAR;
                    end
                end
                
                COUNT: begin
                    if (valid_in) begin
                        found <= 1'b0;
                        found_index <= 4'd0;
                        
                        // Search for existing key
                        for (i = 0; i < 16; i = i + 1) begin
                            if (!found) begin
                                if (keys[i] == data_in && counts[i] != 8'd0) begin
                                    found <= 1'b1;
                                    found_index <= i;
                                end
                                else if (keys[i] == 8'd0 && !found) begin
                                    found_index <= i;
                                end
                            end
                        end
                        
                        // Update counts
                        if (found) begin
                            counts[found_index] <= counts[found_index] + 8'd1;
                        end else begin
                            keys[found_index] <= data_in;
                            counts[found_index] <= 8'd1;
                        end
                    end
                    
                    if (done_in) begin
                        next_state <= OUTPUT;
                        output_index <= 5'd0;
                    end else begin
                        next_state <= COUNT;
                    end
                end
                
                OUTPUT: begin
                    // Output non-zero entries
                    if (keys[output_index] != 8'd0) begin
                        key_out <= keys[output_index];
                        count_out <= counts[output_index];
                        valid_out <= 1'b1;
                    end
                    
                    output_index <= output_index + 5'd1;
                    
                    if (output_index == 5'd15) begin
                        next_state <= COMPLETE;
                    end else begin
                        next_state <= OUTPUT;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule
module color_code_generator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [3:0] p_mask,
    output reg [3:0] output_value,
    output reg output_valid,
    output reg done
);

// State encoding
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] INIT     = 3'd1;
localparam [2:0] OUTPUT   = 3'd2;
localparam [2:0] SEARCH   = 3'd3;
localparam [2:0] COMPLETE = 3'd4;

// Internal registers
reg [2:0] state;
reg [2:0] next_state;
reg [3:0] current_value;
reg [3:0] counter;
reg [15:0] visited;
reg [3:0] search_idx;
reg found_next;
reg [3:0] next_candidate;

// Combinational helper signals
reg [15:0] visited_nxt;
reg [3:0] search_idx_nxt;
reg [2:0] state_nxt;
reg current_value_nxt_en;
reg [3:0] current_value_nxt;

// Helper function for Hamming distance (combinational)
function [2:0] hamming_dist;
    input [3:0] a;
    input [3:0] b;
    integer i;
    reg [3:0] xor_result;
    begin
        xor_result = a ^ b;
        hamming_dist = 0;
        for (i = 0; i < 4; i = i + 1) begin
            if (xor_result[i]) hamming_dist = hamming_dist + 1;
        end
    end
endfunction

// Combinational logic for next state decision
always @(*) begin
    // Default assignments
    next_state = state;
    visited_nxt = visited;
    search_idx_nxt = search_idx;
    current_value_nxt = current_value;
    current_value_nxt_en = 1'b0;
    found_next = 1'b0;
    next_candidate = 4'd0;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT;
            end
        end
        
        INIT: begin
            // Check validity of n
            if (n == 2'd0 || n > 2'd4) begin
                next_state = COMPLETE;
            end else begin
                next_state = OUTPUT;
                // Reset for new sequence
                current_value_nxt_en = 1'b1;
                current_value_nxt = 4'd0;
                visited_nxt = 16'b1;
            end
        end
        
        OUTPUT: begin
            // If all elements output, go to complete
            if (counter == (4'd1 << n) - 4'd1) begin
                next_state = COMPLETE;
            end else begin
                next_state = SEARCH;
                search_idx_nxt = 4'd0;
            end
        end
        
        SEARCH: begin
            // Search for next valid value
            if (search_idx < (4'd1 << n)) begin
                // Check if not visited
                if (!visited[search_idx]) begin
                    // Check Hamming distance
                    if (p_mask[hamming_dist(current_value, search_idx) - 3'd1]) begin
                        found_next = 1'b1;
                        next_candidate = search_idx;
                        next_state = OUTPUT;
                        visited_nxt = visited | (16'b1 << search_idx);
                        current_value_nxt_en = 1'b1;
                        current_value_nxt = search_idx;
                    end else begin
                        search_idx_nxt = search_idx + 4'd1;
                    end
                end else begin
                    search_idx_nxt = search_idx + 4'd1;
                end
            end else begin
                // No valid next state found
                next_state = COMPLETE;
            end
        end
        
        COMPLETE: begin
            if (!start) begin
                next_state = IDLE;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_value <= 4'd0;
        counter <= 4'd0;
        visited <= 16'd0;
        search_idx <= 4'd0;
        output_value <= 4'd0;
        output_valid <= 1'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        visited <= visited_nxt;
        search_idx <= search_idx_nxt;
        
        if (current_value_nxt_en) begin
            current_value <= current_value_nxt;
        end
        
        case (state)
            IDLE: begin
                output_valid <= 1'b0;
                done <= 1'b0;
            end
            
            INIT: begin
                counter <= 4'd0;
            end
            
            OUTPUT: begin
                output_value <= current_value;
                output_valid <= 1'b1;
                counter <= counter + 4'd1;
            end
            
            SEARCH: begin
                output_valid <= 1'b0;
            end
            
            COMPLETE: begin
                output_valid <= 1'b0;
                done <= 1'b1;
            end
            
            default: begin
                output_valid <= 1'b0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule
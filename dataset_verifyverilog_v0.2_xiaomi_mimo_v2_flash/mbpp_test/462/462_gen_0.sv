module power_set_generator (
    input clk,
    input rst_n,
    input start,
    input [3:0] valid_mask,
    input [7:0] element_0,
    input [7:0] element_1,
    input [7:0] element_2,
    input [7:0] element_3,
    output reg [7:0] output_element,
    output reg output_valid,
    output reg output_done,
    output reg [3:0] output_indices
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam GENERATE = 2'b01;
    localparam OUTPUT_ELEMENT = 2'b10;
    localparam DONE = 2'b11;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] subset_counter, next_subset_counter; // Iterates 0 to 15
    reg [3:0] current_mask, next_current_mask; // The subset bitmask currently being processed
    reg [3:0] bit_position, next_bit_position; // Tracks which bit to output (0 to 3)
    reg [3:0] valid_mask_reg; // Store valid_mask
    reg [7:0] elements_reg [0:3]; // Store elements

    // Combinatorial logic for next state and outputs
    reg [7:0] next_output_element;
    reg next_output_valid;
    reg next_output_done;
    reg [3:0] next_output_indices;
    reg [1:0] found_idx;
    integer i;

    // State Transition and Output Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_subset_counter = subset_counter;
        next_current_mask = current_mask;
        next_bit_position = bit_position;
        next_output_element = output_element;
        next_output_valid = 1'b0;
        next_output_done = 1'b0;
        next_output_indices = current_mask;
        found_idx = 2'b00;

        case (state)
            IDLE: begin
                next_output_valid = 1'b0;
                next_output_done = 1'b0;
                next_output_indices = 4'b0000;
                next_output_element = 8'h00;
                if (start) begin
                    next_state = GENERATE;
                    next_subset_counter = 4'b0000;
                    next_bit_position = 4'b0000;
                    next_current_mask = 4'b0000;
                    next_output_indices = 4'b0000;
                end else begin
                    next_state = IDLE;
                end
            end

            GENERATE: begin
                // Check if current subset is valid (intersects with valid_mask)
                if (subset_counter == 16) begin
                    next_state = DONE;
                    next_output_done = 1'b1;
                    next_output_valid = 1'b0;
                end else begin
                    // Start processing current subset
                    next_current_mask = subset_counter;
                    next_output_indices = subset_counter;
                    next_bit_position = 4'b0000; // Start checking from bit 0
                    
                    // Check intersection immediately
                    if ((subset_counter & valid_mask_reg) != 4'b0000) begin
                        next_state = OUTPUT_ELEMENT;
                    end else begin
                        // Empty intersection (either subset empty or no valid bits)
                        // Skip to next subset
                        next_state = GENERATE;
                        next_subset_counter = subset_counter + 1;
                        next_output_indices = 4'b0000; // Clear indices for skipped state
                    end
                end
            end

            OUTPUT_ELEMENT: begin
                // Find next set bit in current_mask starting from bit_position
                // We iterate bit_position 0 to 3
                
                // Find the next valid bit logic
                // We use a priority encoder logic from bit_position onwards
                // If bit_position is beyond 3, we are done with this subset
                
                if (bit_position > 3) begin
                    // Finished outputting elements for this subset
                    next_subset_counter = subset_counter + 1;
                    next_state = GENERATE;
                    next_output_valid = 1'b0;
                    next_output_indices = 4'b0000;
                end else begin
                    // Check current bit position
                    if (current_mask[bit_position]) begin
                        // This bit is set. Output element.
                        next_output_valid = 1'b1;
                        case (bit_position)
                            4'd0: next_output_element = elements_reg[0];
                            4'd1: next_output_element = elements_reg[1];
                            4'd2: next_output_element = elements_reg[2];
                            4'd3: next_output_element = elements_reg[3];
                            default: next_output_element = 8'h00;
                        endcase
                        next_bit_position = bit_position + 1;
                        next_state = OUTPUT_ELEMENT; // Stay in this state to check next bit
                        next_subset_counter = subset_counter; // Hold subset counter
                        next_output_indices = current_mask;
                    end else begin
                        // Bit not set, check next bit in same cycle? 
                        // To keep it a single cycle per element, we need a loop or priority logic.
                        // Since this is combinational block, we can look ahead or just advance bit_position.
                        // To strictly follow "one element per clock cycle", we should not pack multiple elements in one cycle.
                        // So we just advance position.
                        next_output_valid = 1'b0; // No output for this cycle
                        next_bit_position = bit_position + 1;
                        next_state = OUTPUT_ELEMENT;
                        next_subset_counter = subset_counter;
                        next_output_indices = current_mask;
                    end
                end
            end

            DONE: begin
                next_state = DONE;
                next_output_done = 1'b1;
                next_output_valid = 1'b0;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_counter <= 4'b0;
            current_mask <= 4'b0;
            bit_position <= 4'b0;
            output_element <= 8'b0;
            output_valid <= 1'b0;
            output_done <= 1'b0;
            output_indices <= 4'b0;
            valid_mask_reg <= 4'b0;
            elements_reg[0] <= 8'b0;
            elements_reg[1] <= 8'b0;
            elements_reg[2] <= 8'b0;
            elements_reg[3] <= 8'b0;
        end else begin
            state <= next_state;
            subset_counter <= next_subset_counter;
            current_mask <= next_current_mask;
            bit_position <= next_bit_position;
            output_element <= next_output_element;
            output_valid <= next_output_valid;
            output_done <= next_output_done;
            output_indices <= next_output_indices;
            
            // Latch inputs only at start or IDLE to save power/stability
            if (start) begin
                valid_mask_reg <= valid_mask;
                elements_reg[0] <= element_0;
                elements_reg[1] <= element_1;
                elements_reg[2] <= element_2;
                elements_reg[3] <= element_3;
            end
        end
    end

endmodule
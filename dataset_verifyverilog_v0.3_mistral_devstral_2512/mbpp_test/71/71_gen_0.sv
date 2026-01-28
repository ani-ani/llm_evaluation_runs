module comb_sort (
    // Clock and control
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input array (8 elements, 8-bit each)
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    
    // Output array (sorted)
    output reg [7:0] sorted_0,
    output reg [7:0] sorted_1,
    output reg [7:0] sorted_2,
    output reg [7:0] sorted_3,
    output reg [7:0] sorted_4,
    output reg [7:0] sorted_5,
    output reg [7:0] sorted_6,
    output reg [7:0] sorted_7,
    
    // Status
    output reg done
);

// Parameters
parameter NUM_ELEMENTS = 8;
parameter DATA_WIDTH = 8;
parameter MAX_CYCLES = 64;

// Internal memory for sorting
reg [7:0] buffer [0:7];

// State machine states
localparam [1:0] STATE_IDLE = 2'd0;
localparam [1:0] STATE_LOAD = 2'd1;
localparam [1:0] STATE_SORT = 2'd2;
localparam [1:0] STATE_DONE = 2'd3;

reg [1:0] state;
reg [1:0] next_state;

// Sorting variables
reg [7:0] gap;           // Current gap size
reg [7:0] next_gap;
reg swapped;             // Swapped flag
reg next_swapped;
reg [3:0] i;             // Loop counter
reg [3:0] next_i;
reg [5:0] cycle_count;   // Safety timeout
reg [5:0] next_cycle_count;

// Next state logic
always @(*) begin
    next_state = state;
    next_gap = gap;
    next_swapped = swapped;
    next_i = i;
    next_cycle_count = cycle_count;
    
    case (state)
        STATE_IDLE: begin
            if (start) begin
                next_state = STATE_LOAD;
                next_cycle_count = 6'd0;
            end
        end
        
        STATE_LOAD: begin
            // Load input array into buffer
            next_state = STATE_SORT;
            next_gap = 8'd8;  // Start with gap = size
            next_swapped = 1'b1;      // Force first iteration
            next_i = 4'd0;
        end
        
        STATE_SORT: begin
            // Check for completion
            if (gap <= 8'd1 && !swapped) begin
                next_state = STATE_DONE;
            end else if (cycle_count >= MAX_CYCLES) begin
                // Safety timeout
                next_state = STATE_DONE;
            end else begin
                // Perform one iteration of bubble sort with current gap
                if (i < (NUM_ELEMENTS - gap)) begin
                    // Compare and swap if needed
                    // This is handled in combinational block below
                    next_i = i + 4'd1;
                    // If we found a swap, mark swapped flag
                    if (buffer[i] > buffer[i+gap]) begin
                        next_swapped = 1'b1;
                    end
                end else begin
                    // End of this pass
                    next_i = 4'd0;
                    next_cycle_count = cycle_count + 6'd1;
                    
                    // Calculate next gap
                    if (gap > 1) begin
                        // gap = gap / 1.3 ≈ gap * 13 / 10
                        next_gap = (gap * 13) >> 3;  // Div by 8, ~1.625, slightly faster
                        if (next_gap < 1) next_gap = 1;
                    end else begin
                        next_gap = 0;
                    end
                    
                    // Reset swapped flag for next pass
                    next_swapped = 1'b0;
                end
            end
        end
        
        STATE_DONE: begin
            // Hold done state until reset
            if (!start) begin
                next_state = STATE_IDLE;
            end
        end
        
        default: next_state = STATE_IDLE;
    endcase
end

// Sequential state update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        done <= 1'b0;
        gap <= 8'd0;
        swapped <= 1'b0;
        i <= 4'd0;
        cycle_count <= 6'd0;
        // Reset output
        sorted_0 <= 8'd0;
        sorted_1 <= 8'd0;
        sorted_2 <= 8'd0;
        sorted_3 <= 8'd0;
        sorted_4 <= 8'd0;
        sorted_5 <= 8'd0;
        sorted_6 <= 8'd0;
        sorted_7 <= 8'd0;
    end else begin
        state <= next_state;
        gap <= next_gap;
        swapped <= next_swapped;
        i <= next_i;
        cycle_count <= next_cycle_count;
        
        // Load operation
        if (state == STATE_LOAD) begin
            buffer[0] <= arr_0;
            buffer[1] <= arr_1;
            buffer[2] <= arr_2;
            buffer[3] <= arr_3;
            buffer[4] <= arr_4;
            buffer[5] <= arr_5;
            buffer[6] <= arr_6;
            buffer[7] <= arr_7;
        end
        
        // Sort operation - perform swap if needed
        if (state == STATE_SORT && i < (NUM_ELEMENTS - gap)) begin
            if (buffer[i] > buffer[i+gap]) begin
                // Swap
                buffer[i] <= buffer[i+gap];
                buffer[i+gap] <= buffer[i];
            end
        end
        
        // Done operation - copy to output
        if (state == STATE_DONE) begin
            sorted_0 <= buffer[0];
            sorted_1 <= buffer[1];
            sorted_2 <= buffer[2];
            sorted_3 <= buffer[3];
            sorted_4 <= buffer[4];
            sorted_5 <= buffer[5];
            sorted_6 <= buffer[6];
            sorted_7 <= buffer[7];
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end
end

endmodule
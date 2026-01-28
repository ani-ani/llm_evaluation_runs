module SublistMaxFinder(
    input clk,
    input rst_n,
    input start,
    input [15:0] sublists [0:3],
    input [3:0] valid_mask,
    output reg [3:0] max_length,
    output reg [7:0] max_sublist [0:3],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] SCAN    = 3'd2;
    localparam [2:0] DECIDE  = 3'd3;
    localparam [2:0] OUTPUT  = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers
    reg [3:0] current_length;
    reg [3:0] current_max_length;
    reg [3:0] current_sublist_index;
    reg [3:0] max_sublist_index;
    reg [7:0] current_sublist [0:3];

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_length <= 4'd0;
            current_max_length <= 4'd0;
            current_sublist_index <= 4'd0;
            max_sublist_index <= 4'd0;
            done <= 1'b0;
            max_length <= 4'd0;
            
            // Initialize max_sublist array
            max_sublist[0] <= 8'd0;
            max_sublist[1] <= 8'd0;
            max_sublist[2] <= 8'd0;
            max_sublist[3] <= 8'd0;
            
            // Initialize current_sublist array
            current_sublist[0] <= 8'd0;
            current_sublist[1] <= 8'd0;
            current_sublist[2] <= 8'd0;
            current_sublist[3] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    current_sublist_index <= 4'd0;
                    current_max_length <= 4'd0;
                    max_sublist_index <= 4'd0;
                    next_state <= SCAN;
                end

                SCAN: begin
                    // Load current sublist
                    current_sublist[0] <= sublists[current_sublist_index][0];
                    current_sublist[1] <= sublists[current_sublist_index][1];
                    current_sublist[2] <= sublists[current_sublist_index][2];
                    current_sublist[3] <= sublists[current_sublist_index][3];
                    
                    // Count non-zero elements
                    current_length <= 4'd0;
                    if (current_sublist[0] != 8'd0) current_length <= current_length + 4'd1;
                    if (current_sublist[1] != 8'd0) current_length <= current_length + 4'd1;
                    if (current_sublist[2] != 8'd0) current_length <= current_length + 4'd1;
                    if (current_sublist[3] != 8'd0) current_length <= current_length + 4'd1;
                    
                    // Check if this sublist is valid
                    if (valid_mask[current_sublist_index]) begin
                        // Compare with current max
                        if (current_length > current_max_length) begin
                            current_max_length <= current_length;
                            max_sublist_index <= current_sublist_index;
                            max_sublist[0] <= current_sublist[0];
                            max_sublist[1] <= current_sublist[1];
                            max_sublist[2] <= current_sublist[2];
                            max_sublist[3] <= current_sublist[3];
                        end else if (current_length == current_max_length) begin
                            // Tie-break: compare first element
                            if (current_sublist[0] > max_sublist[0]) begin
                                max_sublist_index <= current_sublist_index;
                                max_sublist[0] <= current_sublist[0];
                                max_sublist[1] <= current_sublist[1];
                                max_sublist[2] <= current_sublist[2];
                                max_sublist[3] <= current_sublist[3];
                            end
                        end
                    end
                    
                    // Move to next sublist or finish
                    if (current_sublist_index == 4'd3) begin
                        next_state <= DECIDE;
                    end else begin
                        current_sublist_index <= current_sublist_index + 4'd1;
                        next_state <= SCAN;
                    end
                end

                DECIDE: begin
                    max_length <= current_max_length;
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            
            // Cycle counter for safety
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                end
            end
        end
    end
endmodule
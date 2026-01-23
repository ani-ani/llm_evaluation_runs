module sort_even(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] data_in [0:7],
    output reg [7:0] data_out [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam READ = 3'b001;
    localparam SORT_EVEN = 3'b010;
    localparam WRITE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    
    // Internal buffer for sorting (8 elements)
    reg [7:0] buffer [0:7];
    
    // Bubble sort registers for even indices
    // Even indices: 0, 2, 4, 6
    reg [1:0] i_pass; // Outer loop counter (0 to 3)
    reg [1:0] j_index; // Inner loop counter (0, 2, 4 for comparison pairs)
    reg [1:0] sort_step; // Step within sorting cycle
    
    // Counter for READ state (copy all 8 elements)
    reg [3:0] read_idx;
    
    // Counter for WRITE state (copy all 8 elements)
    reg [3:0] write_idx;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = READ;
            end
            READ: begin
                if (read_idx == 4'd8)
                    next_state = SORT_EVEN;
            end
            SORT_EVEN: begin
                // Bubble sort: 3 passes max for 4 elements
                // Passes: 0, 1, 2 (3 passes)
                // Each pass involves comparisons at indices (0,2), (2,4), (4,6)
                // We use sort_step to handle comparison and swap
                if (i_pass == 2'd3 && sort_step == 2'd2)
                    next_state = WRITE;
            end
            WRITE: begin
                if (write_idx == 4'd8)
                    next_state = DONE;
            end
            DONE: begin
                if (!start)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and internal signals
            done <= 1'b0;
            read_idx <= 4'd0;
            write_idx <= 4'd0;
            i_pass <= 2'd0;
            j_index <= 2'd0;
            sort_step <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    read_idx <= 4'd0;
                    write_idx <= 4'd0;
                    i_pass <= 2'd0;
                    j_index <= 2'd0;
                    sort_step <= 2'd0;
                end
                
                READ: begin
                    // Load data_in into buffer
                    if (read_idx < 4'd8) begin
                        buffer[read_idx] <= data_in[read_idx];
                        read_idx <= read_idx + 1'b1;
                    end
                end
                
                SORT_EVEN: begin
                    // Bubble sort on even indices: 0, 2, 4, 6
                    // Three passes (i_pass: 0, 1, 2)
                    // Inner loop runs 3 times per pass (comparing adjacent even indices)
                    // Indices to compare: (0,2), (2,4), (4,6)
                    
                    case (sort_step)
                        2'd0: begin
                            // Setup comparison - no operation, just increment step
                            sort_step <= 2'd1;
                        end
                        2'd1: begin
                            // Perform comparison and conditionally swap
                            // j_index cycles through 0, 2, 4 (comparing pairs j and j+2)
                            if (j_index < 3'd4) begin // indices 0, 2, 4 (since 4+2=6)
                                if (buffer[j_index] > buffer[j_index + 2'd2]) begin
                                    // Swap
                                    buffer[j_index] <= buffer[j_index + 2'd2];
                                    buffer[j_index + 2'd2] <= buffer[j_index];
                                end
                                sort_step <= 2'd2;
                            end else begin
                                // If j_index >= 4, we are done with this pass
                                sort_step <= 2'd2;
                            end
                        end
                        2'd2: begin
                            // Increment j_index or move to next pass
                            if (j_index < 3'd4) begin
                                j_index <= j_index + 2'd2; // Move to next pair (0->2->4->6)
                                sort_step <= 2'd0; // Reset for next comparison in this pass
                            end else begin
                                // End of current pass
                                j_index <= 2'd0; // Reset j for next pass
                                i_pass <= i_pass + 1'b1;
                                sort_step <= 2'd0;
                            end
                        end
                    endcase
                end
                
                WRITE: begin
                    // Copy buffer to data_out
                    if (write_idx < 4'd8) begin
                        data_out[write_idx] <= buffer[write_idx];
                        write_idx <= write_idx + 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
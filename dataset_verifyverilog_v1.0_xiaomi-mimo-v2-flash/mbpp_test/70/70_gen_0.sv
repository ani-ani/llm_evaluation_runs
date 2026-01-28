module tuple_length_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] tuple_lengths [0:7],
    output reg equal,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] base_length;
    reg [3:0] index;
    reg [3:0] stored_lengths [0:7];
    reg [3:0] temp_length;
    reg mismatch_found;
    reg [4:0] cycle_count; // To enforce 16 cycle limit
    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            equal <= 1'b0;
            done <= 1'b0;
            base_length <= 4'd0;
            index <= 4'd0;
            mismatch_found <= 1'b0;
            cycle_count <= 5'd0;
            // Initialize stored_lengths array
            for (i = 0; i < 8; i = i + 1) begin
                stored_lengths[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    // Clear done signal when idle
                    done <= 1'b0;
                    mismatch_found <= 1'b0;
                    cycle_count <= 5'd0;
                    index <= 4'd0;
                    
                    if (start) begin
                        // Latch input values
                        base_length <= tuple_lengths[0];
                        for (i = 0; i < 8; i = i + 1) begin
                            stored_lengths[i] <= tuple_lengths[i];
                        end
                        
                        // Handle single tuple edge case immediately
                        // If base_length is valid (1-8) and others ignored, result is 1
                        // If base_length is 0 (empty), treat as valid length match
                        next_state <= COMPARE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Check current index against base_length
                    temp_length <= stored_lengths[index + 4'd1]; // Get next tuple length
                    
                    // Compare logic
                    if (index < 7) begin
                        if (stored_lengths[index + 4'd1] != base_length) begin
                            mismatch_found <= 1'b1;
                        end
                        
                        // Move to next tuple
                        index <= index + 4'd1;
                        next_state <= COMPARE;
                    end else begin
                        // Finished comparing all tuples
                        next_state <= FINISH;
                    end
                    
                    // Safety timeout (16 cycles max)
                    if (cycle_count >= 5'd15) begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    // Determine final result
                    // If mismatch_found is 1, equal is 0
                    // If mismatch_found is 0, equal is 1
                    equal <= !mismatch_found;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule
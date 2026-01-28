module WheelRotationSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0][1:0] wheel0,
    input wire [7:0][1:0] wheel1,
    input wire [7:0][1:0] wheel2,
    input wire [2:0] length,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK_ROT = 3'd2;
    localparam [2:0] CHECK_COLS = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Registers and variables
    reg [2:0] state;
    reg [2:0] rot0, rot1, rot2;
    reg [2:0] best_rot0, best_rot1, best_rot2;
    reg [7:0] valid_flag;
    reg [3:0] current_total;
    reg [3:0] min_total;
    reg [2:0] col;
    reg [2:0] i;
    reg [2:0] count;
    reg [2:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper functions for circular indexing
    function automatic [2:0] get_rotated_index;
        input [2:0] orig_idx;
        input [2:0] rot;
        input [2:0] len;
        reg [2:0] temp_idx;
        begin
            temp_idx = (orig_idx + rot) % len;
            get_rotated_index = temp_idx;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            rot0 <= 3'd0;
            rot1 <= 3'd0;
            rot2 <= 3'd0;
            best_rot0 <= 3'd0;
            best_rot1 <= 3'd0;
            best_rot2 <= 3'd0;
            valid_flag <= 8'd0;
            current_total <= 4'd0;
            min_total <= 4'd15;
            col <= 3'd0;
            i <= 3'd0;
            count <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    min_total <= 4'd15; // Initialize to max value (15)
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize for first rotation combination
                    rot0 <= 3'd0;
                    rot1 <= 3'd0;
                    rot2 <= 3'd0;
                    current_total <= 4'd0;
                    valid_flag <= 8'd1; // Assume valid until proven otherwise
                    cycle_count <= cycle_count + 8'd1;
                    state <= CHECK_COLS;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                CHECK_ROT: begin
                    // Move to next rotation combination
                    // This is a triple nested loop: rot0, rot1, rot2
                    if (rot0 == length) begin
                        // All combinations checked
                        if (min_total == 4'd15) begin
                            result <= 4'd15; // -1 if impossible
                        end else begin
                            result <= min_total;
                        end
                        state <= DONE;
                    end else begin
                        // Check if columns are valid for this rotation combination
                        valid_flag <= 8'd1;
                        col <= 3'd0;
                        state <= CHECK_COLS;
                        cycle_count <= cycle_count + 8'd1;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= DONE;
                        end
                    end
                end

                CHECK_COLS: begin
                    // Check each column for distinct letters
                    if (col >= length) begin
                        // All columns checked
                        if (valid_flag) begin
                            state <= UPDATE_MIN;
                        end else begin
                            // Invalid combination, move to next
                            // Update rot2
                            if (rot2 == length - 1) begin
                                rot2 <= 3'd0;
                                // Update rot1
                                if (rot1 == length - 1) begin
                                    rot1 <= 3'd0;
                                    // Update rot0
                                    rot0 <= rot0 + 3'd1;
                                end else begin
                                    rot1 <= rot1 + 3'd1;
                                end
                            end else begin
                                rot2 <= rot2 + 3'd1;
                            end
                            state <= CHECK_ROT;
                        end
                    end else begin
                        // Get rotated indices
                        // Calculate index for each wheel
                        // We need to calculate the index where data comes from
                        // For wheel0, original position `col` moves to `col + rot0` (circular)
                        // So data at rotated position `col` comes from `col - rot0` (circular)
                        // Or equivalently, data from `col` moves to `col + rot0`
                        // Let's get data at column `col` after rotation `rot`:
                        // data_at_col = data_original[(col - rot + length) % length]
                        
                        // Check wheel0[0] vs wheel1[0] vs wheel2[0]
                        // Using modulo arithmetic: (a - b) mod n
                        // Index = (col - rot + length) % length
                        
                        // Let's compute indices inline to avoid function call issues with Icarus
                        // Since length <= 8, we can precompute or handle logic simply
                        
                        // Simple logic for index calculation:
                        // For wheel0: (col - rot0) + length if negative
                        // But since we can't use % easily in synthesis for variables, let's use logic
                        
                        // We will check the values directly:
                        // Value at column `col` after rotation `rot` is the original value at `(col - rot) mod len`
                        
                        // To check if distinct: v0 != v1, v0 != v2, v1 != v2
                        
                        // We need to fetch the data. 
                        // Since we can't use dynamic indexing easily in Verilog for synthesis without knowing width,
                        // and we have fixed max 8 elements, we can use a case statement or if-else chain.
                        
                        // Optimized approach: Check validity
                        // Value 0 = A (2'b00), 1 = B (2'b01), 2 = C (2'b10)
                        
                        // Let's define which original index corresponds to current column `col`
                        // idx0 = (col - rot0 + length) % length
                        // Since length is small (<=8), we can implement modulo logic using conditions.
                        
                        // Helper logic for index:
                        reg [2:0] idx0, idx1, idx2;
                        reg [1:0] val0, val1, val2;
                        
                        // Calculate idx0
                        if (col >= rot0) idx0 = col - rot0;
                        else idx0 = col + (length - rot0);
                        
                        // Calculate idx1
                        if (col >= rot1) idx1 = col - rot1;
                        else idx1 = col + (length - rot1);
                        
                        // Calculate idx2
                        if (col >= rot2) idx2 = col - rot2;
                        else idx2 = col + (length - rot2);
                        
                        // Get values based on index (using ternary or if-else for 8 options)
                        // Wheel0[idx0]
                        case (idx0)
                            3'd0: val0 = wheel0[0];
                            3'd1: val0 = wheel0[1];
                            3'd2: val0 = wheel0[2];
                            3'd3: val0 = wheel0[3];
                            3'd4: val0 = wheel0[4];
                            3'd5: val0 = wheel0[5];
                            3'd6: val0 = wheel0[6];
                            3'd7: val0 = wheel0[7];
                        endcase
                        
                        // Wheel1[idx1]
                        case (idx1)
                            3'd0: val1 = wheel1[0];
                            3'd1: val1 = wheel1[1];
                            3'd2: val1 = wheel1[2];
                            3'd3: val1 = wheel1[3];
                            3'd4: val1 = wheel1[4];
                            3'd5: val1 = wheel1[5];
                            3'd6: val1 = wheel1[6];
                            3'd7: val1 = wheel1[7];
                        endcase
                        
                        // Wheel2[idx2]
                        case (idx2)
                            3'd0: val2 = wheel2[0];
                            3'd1: val2 = wheel2[1];
                            3'd2: val2 = wheel2[2];
                            3'd3: val2 = wheel2[3];
                            3'd4: val2 = wheel2[4];
                            3'd5: val2 = wheel2[5];
                            3'd6: val2 = wheel2[6];
                            3'd7: val2 = wheel2[7];
                        endcase
                        
                        // Check distinctness
                        if (val0 == val1 || val0 == val2 || val1 == val2) begin
                            valid_flag <= 1'b0;
                        end
                        
                        col <= col + 3'd1;
                        state <= CHECK_COLS;
                    end
                end

                UPDATE_MIN: begin
                    // Calculate total rotations: rot0 + rot1 + rot2
                    // Note: We count left rotations. 
                    // Since we rotate left, rot amount is the number of steps.
                    // Or we could choose min(rot, length - rot).
                    // Problem says: "rotate left/right by 1 position" and "total rotations = sum of absolute rotation amounts"
                    // If we interpret "rotations" as steps taken, it's just the count.
                    // If we interpret as minimum physical rotation, it's min(rot, len-rot).
                    // "Find minimum rotations" usually implies min physical rotation.
                    // Let's calculate min(rot, len - rot) for each.
                    
                    // For wheel 0
                    reg [2:0] cost0, cost1, cost2;
                    reg [3:0] total;
                    
                    // Cost 0
                    if (rot0 <= length - rot0) cost0 = rot0;
                    else cost0 = length - rot0;
                    
                    // Cost 1
                    if (rot1 <= length - rot1) cost1 = rot1;
                    else cost1 = length - rot1;
                    
                    // Cost 2
                    if (rot2 <= length - rot2) cost2 = rot2;
                    else cost2 = length - rot2;
                    
                    total = cost0 + cost1 + cost2;
                    
                    if (total < min_total) begin
                        min_total <= total;
                        best_rot0 <= rot0;
                        best_rot1 <= rot1;
                        best_rot2 <= rot2;
                    end
                    
                    // Move to next rotation combination
                    // Update rot2
                    if (rot2 == length - 1) begin
                        rot2 <= 3'd0;
                        // Update rot1
                        if (rot1 == length - 1) begin
                            rot1 <= 3'd0;
                            // Update rot0
                            rot0 <= rot0 + 3'd1;
                        end else begin
                            rot1 <= rot1 + 3'd1;
                        end
                    end else begin
                        rot2 <= rot2 + 3'd1;
                    end
                    
                    state <= CHECK_ROT;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
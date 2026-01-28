module wheel_rotation_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] wheel0 [0:7],
    input wire [1:0] wheel1 [0:7],
    input wire [1:0] wheel2 [0:7],
    input wire [2:0] length,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] rot0, rot1, rot2;
    reg [2:0] min_rotations;
    reg found_valid;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd7;
    
    // Internal arrays for rotated wheels
    reg [1:0] rotated0 [0:7];
    reg [1:0] rotated1 [0:7];
    reg [1:0] rotated2 [0:7];
    
    // Initialize arrays
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            rot0 <= 3'd0;
            rot1 <= 3'd0;
            rot2 <= 3'd0;
            min_rotations <= 3'd7;
            found_valid <= 1'b0;
            cycle_count <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                rotated0[i] <= 2'd0;
                rotated1[i] <= 2'd0;
                rotated2[i] <= 2'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        state <= COMPUTE;
                        rot0 <= 3'd0;
                        rot1 <= 3'd0;
                        rot2 <= 3'd0;
                        min_rotations <= 3'd7;
                        found_valid <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 3'd1;
                    
                    // Rotate wheels
                    for (i = 0; i < 8; i = i + 1) begin
                        rotated0[i] <= wheel0[(i + rot0) % length];
                        rotated1[i] <= wheel1[(i + rot1) % length];
                        rotated2[i] <= wheel2[(i + rot2) % length];
                    end
                    
                    // Check if current configuration is valid
                    reg valid;
                    valid = 1'b1;
                    for (i = 0; i < length; i = i + 1) begin
                        if ((rotated0[i] == rotated1[i]) ||
                            (rotated0[i] == rotated2[i]) ||
                            (rotated1[i] == rotated2[i])) begin
                            valid = 1'b0;
                        end
                    end
                    
                    // Update minimum rotations if valid
                    if (valid) begin
                        reg [3:0] total_rot;
                        total_rot = rot0 + rot1 + rot2;
                        if (total_rot < min_rotations) begin
                            min_rotations <= total_rot;
                            found_valid <= 1'b1;
                        end
                    end
                    
                    // Increment rotations
                    rot2 <= rot2 + 3'd1;
                    if (rot2 == length) begin
                        rot2 <= 3'd0;
                        rot1 <= rot1 + 3'd1;
                        if (rot1 == length) begin
                            rot1 <= 3'd0;
                            rot0 <= rot0 + 3'd1;
                            if (rot0 == length) begin
                                state <= FINISH;
                            end
                        end
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    if (found_valid) begin
                        result <= min_rotations;
                    end else begin
                        result <= 4'd15;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
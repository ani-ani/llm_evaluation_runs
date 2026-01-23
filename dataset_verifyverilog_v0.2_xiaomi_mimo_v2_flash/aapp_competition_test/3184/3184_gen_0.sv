module camera_coverage(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] a_i [0:7],
    input [7:0] b_i [0:7],
    output reg [3:0] result,
    output reg done,
    output reg impossible
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PREPROCESS = 3'b001;
    localparam SEARCH = 3'b010;
    localparam DONE = 3'b011;

    reg [2:0] state;
    reg [2:0] cam_idx;
    reg [7:0] subset_mask;
    
    // Storage for camera masks
    reg [7:0] cam_mask [0:7];
    
    // Target coverage
    wire [7:0] target;
    assign target = (n == 0) ? 8'b0 : ((1 << n) - 1);
    
    // Combinational helper for coverage
    wire [7:0] current_coverage;
    assign current_coverage = 
        (cam_mask[0] & {8{subset_mask[0]}}) |
        (cam_mask[1] & {8{subset_mask[1]}}) |
        (cam_mask[2] & {8{subset_mask[2]}}) |
        (cam_mask[3] & {8{subset_mask[3]}}) |
        (cam_mask[4] & {8{subset_mask[4]}}) |
        (cam_mask[5] & {8{subset_mask[5]}}) |
        (cam_mask[6] & {8{subset_mask[6]}}) |
        (cam_mask[7] & {8{subset_mask[7]}});

    // Combinational helper for popcount
    wire [3:0] popcount;
    assign popcount = subset_mask[0] + subset_mask[1] + subset_mask[2] + subset_mask[3] + 
                      subset_mask[4] + subset_mask[5] + subset_mask[6] + subset_mask[7];

    // Registers for minimum tracking
    reg [3:0] min_cameras;
    reg found_solution;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            impossible <= 0;
            cam_idx <= 0;
            subset_mask <= 8'h00;
            min_cameras <= 4'd15; // Max possible + 1 (8+7)
            found_solution <= 0;
            // Initialize cam_mask to avoid latch inference
            cam_mask[0] <= 0; cam_mask[1] <= 0; cam_mask[2] <= 0; cam_mask[3] <= 0;
            cam_mask[4] <= 0; cam_mask[5] <= 0; cam_mask[6] <= 0; cam_mask[7] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    cam_idx <= 0;
                    subset_mask <= 8'h01; // Start with first camera
                    min_cameras <= 4'd15;
                    found_solution <= 0;
                    if (start) state <= PREPROCESS;
                end

                PREPROCESS: begin
                    // Calculate mask for camera[cam_idx]
                    if (cam_idx < 8) begin
                        // Mask generation logic
                        // Walls are 1..n. Bits are 0..n-1.
                        if (a_i[cam_idx] <= b_i[cam_idx]) begin
                            // Normal interval [a, b]
                            // Check validity
                            if (a_i[cam_idx] >= 1 && a_i[cam_idx] <= n && b_i[cam_idx] >= 1 && b_i[cam_idx] <= n && a_i[cam_idx] <= b_i[cam_idx]) begin
                                // Set bits a-1 to b-1
                                cam_mask[cam_idx] <= ((1 << b_i[cam_idx]) - (1 << (a_i[cam_idx] - 1)));
                            end else begin
                                cam_mask[cam_idx] <= 0;
                            end
                        end else begin
                            // Wrap around interval [a, n] U [1, b]
                            if (a_i[cam_idx] >= 1 && a_i[cam_idx] <= n && b_i[cam_idx] >= 1 && b_i[cam_idx] <= n) begin
                                // Bits a-1 to n-1 AND 0 to b-1
                                // Top part: (1<<n) - (1<<(a-1)) creates bits a-1 to n-1 in n-bit width
                                // But we need to mask to n bits because (1<<n) is out of range for n-bit logic if we want to stay in n bits.
                                // Actually, in Verilog, 1<<n is 32-bit. We just need to keep the valid bits.
                                // Since we only care about bits 0..n-1, we can mask result.
                                // Top: bits [a-1 : n-1] set. Formula: ((1 << n) >> (a-1)) shifted? No.
                                // Easier: set bits 0 to b-1. Set bits a-1 to n-1.
                                // Mask = ((1 << b_i[cam_idx]) - 1) | ( {n{1'b1}} << (a_i[cam_idx] - 1) );
                                // {n{1'b1}} is 0xFF for n=8, but we need to truncate based on n.
                                // Let's use: ((1 << n) - 1) gives full n-bit mask.
                                // We want bits a-1..n-1. That's full mask AND NOT ( (1<<(a-1))-1 ).
                                // Wait, (1<<(a-1))-1 gives bits 0..a-2.
                                // So full mask minus that gives a-1..n-1.
                                // So: ( ( (1<<n)-1 ) ^ ( (1<<(a_i[cam_idx]-1))-1 ) )
                                // OR with ( (1<<b_i[cam_idx])-1 )
                                cam_mask[cam_idx] <= 
                                    ( ((1 << n) - 1) ^ ((1 << (a_i[cam_idx] - 1)) - 1) ) | 
                                    ((1 << b_i[cam_idx]) - 1);
                            end else begin
                                cam_mask[cam_idx] <= 0;
                            end
                        end
                        cam_idx <= cam_idx + 1;
                    end else begin
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    // Check current subset_mask
                    if (popcount >= 1 && popcount <= k) begin
                        // Valid subset size
                        if (current_coverage == target) begin
                            // Found a covering subset
                            found_solution <= 1;
                            if (popcount < min_cameras) begin
                                min_cameras <= popcount;
                            end
                        end
                    end
                    
                    // Next subset
                    if (subset_mask == 8'hFF) begin
                        // Done searching all subsets
                        if (found_solution) begin
                            result <= min_cameras;
                        end else begin
                            impossible <= 1;
                            result <= 0;
                        end
                        state <= DONE;
                    end else begin
                        subset_mask <= subset_mask + 1;
                    end
                end

                DONE: begin
                    done <= 1;
                    // Wait for reset or restart
                    if (!start && !rst_n) begin
                        // Standard behavior: stay done until reset
                    end
                end
            endcase
        end
    end

endmodule
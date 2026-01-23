module robotic_arm (
    input clk,
    input rst_n,
    input start,
    input signed [31:0] target_x,
    input signed [31:0] target_y,
    input [31:0] seg_length [0:7],
    input [2:0] num_segments,
    output reg signed [31:0] joint_x [0:7],
    output reg signed [31:0] joint_y [0:7],
    output reg done,
    output reg reachable
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CALC_DIST,
        CHECK_REACH,
        PLACE_JOINTS,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg signed [31:0] total_length;
    reg signed [31:0] target_distance;
    reg signed [31:0] current_x, current_y;
    reg signed [31:0] delta_x, delta_y;
    reg [2:0] joint_counter;
    reg signed [31:0] scale_factor;

    // Fixed-point square root approximation
    function signed [31:0] sqrt_fixed (input signed [31:0] val);
        reg [31:0] x, y;
        integer i;
        
        if (val <= 0) begin
            sqrt_fixed = 0;
        end else begin
            x = val;
            y = 0;
            for (i = 0; i < 16; i = i + 1) begin
                y = (y + (x >> (i + 1))) >> 1;
                x = (x >> (i + 1)) + y;
            end
            sqrt_fixed = y;
        end
    endfunction

    // Fixed-point multiplication
    function signed [31:0] fp_mult (input signed [31:0] a, input signed [31:0] b);
        fp_mult = (a * b) >> 16;
    endfunction

    // Fixed-point division
    function signed [31:0] fp_div (input signed [31:0] a, input signed [31:0] b);
        if (b == 0) begin
            fp_div = 0;
        end else begin
            fp_div = (a << 16) / b;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            reachable <= 0;
            joint_counter <= 0;
            total_length <= 0;
            target_distance <= 0;
            current_x <= 0;
            current_y <= 0;
            delta_x <= 0;
            delta_y <= 0;
            scale_factor <= 0;
            
            // Initialize joint positions
            for (int i = 0; i < 8; i = i + 1) begin
                joint_x[i] <= 0;
                joint_y[i] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_DIST;
                end
            end
            CALC_DIST: begin
                next_state = CHECK_REACH;
            end
            CHECK_REACH: begin
                next_state = PLACE_JOINTS;
            end
            PLACE_JOINTS: begin
                if (joint_counter == num_segments) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (state)
                CALC_DIST: begin
                    // Calculate total arm length
                    total_length = 0;
                    for (int i = 0; i < num_segments; i = i + 1) begin
                        total_length = total_length + seg_length[i];
                    end
                    
                    // Calculate target distance
                    target_distance = sqrt_fixed(fp_mult(target_x, target_x) + fp_mult(target_y, target_y));
                    
                    // Calculate direction vector
                    delta_x = target_x;
                    delta_y = target_y;
                end
                CHECK_REACH: begin
                    // Check if target is reachable
                    if (total_length >= target_distance) begin
                        reachable = 1;
                        scale_factor = 1 << 16; // Q16.16 representation of 1.0
                    end else begin
                        reachable = 0;
                        scale_factor = fp_div(target_distance, total_length);
                    end
                    
                    // Initialize first joint position
                    current_x = 0;
                    current_y = 0;
                    joint_counter = 0;
                end
                PLACE_JOINTS: begin
                    if (joint_counter < num_segments) begin
                        // Calculate segment vector
                        reg signed [31:0] seg_x, seg_y;
                        seg_x = fp_mult(delta_x, scale_factor);
                        seg_y = fp_mult(delta_y, scale_factor);
                        
                        // Scale by segment length
                        seg_x = fp_mult(seg_x, seg_length[joint_counter]);
                        seg_y = fp_mult(seg_y, seg_length[joint_counter]);
                        
                        // Update current position
                        current_x = current_x + seg_x;
                        current_y = current_y + seg_y;
                        
                        // Store joint position
                        joint_x[joint_counter] = current_x;
                        joint_y[joint_counter] = current_y;
                        
                        joint_counter = joint_counter + 1;
                    end
                end
                DONE: begin
                    done = 1;
                end
                default: ;
            endcase
        end
    end

endmodule
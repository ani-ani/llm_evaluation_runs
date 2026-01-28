module FrogRegent (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] start_seq,  // 16x8 bits packed
    input wire [127:0] target_seq, // 16x8 bits packed
    input wire [3:0] n,
    output reg [7:0] cmd_out,
    output reg cmd_valid,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] FIND_FROG  = 3'd2;
    localparam [2:0] BUBBLE     = 3'd3;
    localparam [2:0] CHECK      = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Registers for storage
    reg [7:0] current [0:15];
    reg [7:0] target [0:15];
    
    // Control registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i_idx;          // Outer loop index (0 to N-2)
    reg [3:0] j_idx;          // Inner loop index (bubble position)
    reg [3:0] find_idx;       // Search index for finding correct frog
    reg [16:0] step_count;    // Safety counter (0 to 100000)
    reg found_correct;        // Flag for finding correct frog
    
    // Temporary storage for bubble operation
    reg [7:0] temp_cmd;
    
    // Helper: Compare current and target arrays
    wire arrays_equal;
    reg compare_eq;
    integer k;
    
    always @(*) begin
        compare_eq = 1'b1;
        for (k = 0; k < 16; k = k + 1) begin
            if (k < n) begin
                if (current[k] != target[k]) begin
                    compare_eq = 1'b0;
                end
            end
        end
    end
    assign arrays_equal = compare_eq;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT: begin
                next_state = FIND_FROG;
            end
            FIND_FROG: begin
                if (i_idx >= n - 4'd1)
                    next_state = CHECK;
                else if (current[i_idx] == target[i_idx])
                    next_state = CHECK;
                else if (found_correct)
                    next_state = BUBBLE;
                else
                    next_state = FIND_FROG;
            end
            BUBBLE: begin
                if (j_idx == i_idx)
                    next_state = CHECK;
                else
                    next_state = BUBBLE;
            end
            CHECK: begin
                if (arrays_equal)
                    next_state = FINISH;
                else if (i_idx >= n - 4'd1)
                    next_state = FINISH;
                else if (step_count >= 17'd100000)
                    next_state = FINISH;
                else
                    next_state = FIND_FROG;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer l;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            cmd_valid <= 1'b0;
            cmd_out <= 8'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            find_idx <= 4'd0;
            step_count <= 17'd0;
            found_correct <= 1'b0;
            temp_cmd <= 8'd0;
            for (l = 0; l < 16; l = l + 1) begin
                current[l] <= 8'd0;
                target[l] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    cmd_valid <= 1'b0;
                    i_idx <= 4'd0;
                    j_idx <= 4'd0;
                    find_idx <= 4'd0;
                    step_count <= 17'd0;
                    found_correct <= 1'b0;
                end
                INIT: begin
                    busy <= 1'b1;
                    // Load start_seq into current (unpacked)
                    current[0] <= start_seq[7:0];
                    current[1] <= start_seq[15:8];
                    current[2] <= start_seq[23:16];
                    current[3] <= start_seq[31:24];
                    current[4] <= start_seq[39:32];
                    current[5] <= start_seq[47:40];
                    current[6] <= start_seq[55:48];
                    current[7] <= start_seq[63:56];
                    current[8] <= start_seq[71:64];
                    current[9] <= start_seq[79:72];
                    current[10] <= start_seq[87:80];
                    current[11] <= start_seq[95:88];
                    current[12] <= start_seq[103:96];
                    current[13] <= start_seq[111:104];
                    current[14] <= start_seq[119:112];
                    current[15] <= start_seq[127:120];
                    // Load target_seq into target
                    target[0] <= target_seq[7:0];
                    target[1] <= target_seq[15:8];
                    target[2] <= target_seq[23:16];
                    target[3] <= target_seq[31:24];
                    target[4] <= target_seq[39:32];
                    target[5] <= target_seq[47:40];
                    target[6] <= target_seq[55:48];
                    target[7] <= target_seq[63:56];
                    target[8] <= target_seq[71:64];
                    target[9] <= target_seq[79:72];
                    target[10] <= target_seq[87:80];
                    target[11] <= target_seq[95:88];
                    target[12] <= target_seq[103:96];
                    target[13] <= target_seq[111:104];
                    target[14] <= target_seq[119:112];
                    target[15] <= target_seq[127:120];
                    i_idx <= 4'd0;
                    j_idx <= 4'd0;
                    find_idx <= 4'd0;
                    found_correct <= 1'b0;
                    step_count <= 17'd0;
                    cmd_valid <= 1'b0;
                end
                FIND_FROG: begin
                    cmd_valid <= 1'b0;
                    if (found_correct) begin
                        found_correct <= 1'b0;
                    end else begin
                        // Search for correct frog starting from i_idx+1
                        if (find_idx < n) begin
                            if (current[find_idx] == target[i_idx]) begin
                                j_idx <= find_idx;
                                found_correct <= 1'b1;
                            end
                            find_idx <= find_idx + 4'd1;
                        end else begin
                            // Should not happen if inputs are valid
                            found_correct <= 1'b1; // Force transition
                        end
                    end
                end
                BUBBLE: begin
                    if (j_idx > i_idx) begin
                        // Output cmd for bubble
                        cmd_out <= current[j_idx];
                        cmd_valid <= 1'b1;
                        step_count <= step_count + 17'd1;
                        
                        // Swap current[j_idx] and current[j_idx-1]
                        current[j_idx] <= current[j_idx-1];
                        current[j_idx-1] <= current[j_idx];
                        
                        j_idx <= j_idx - 4'd1;
                        find_idx <= i_idx + 4'd1; // Reset find_idx for next search
                    end else begin
                        cmd_valid <= 1'b0;
                    end
                end
                CHECK: begin
                    cmd_valid <= 1'b0;
                    if (i_idx < n - 4'd1) begin
                        i_idx <= i_idx + 4'd1;
                        find_idx <= i_idx + 4'd1; // Next search starts from i+1
                    end
                    found_correct <= 1'b0;
                end
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    cmd_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule
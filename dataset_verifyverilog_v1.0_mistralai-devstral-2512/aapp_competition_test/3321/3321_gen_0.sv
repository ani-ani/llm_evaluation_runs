module FrogRegent(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] [7:0] start_seq,
    input wire [15:0] [7:0] target_seq,
    input wire [3:0] n,
    output reg [7:0] cmd_out,
    output reg cmd_valid,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] FIND_FROG = 3'd2;
    localparam [2:0] BUBBLE    = 3'd3;
    localparam [2:0] CHECK     = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Current permutation storage
    reg [7:0] current [0:15];

    // State machine registers
    reg [2:0] state, next_state;
    reg [3:0] i, j;
    reg [16:0] step_count;
    reg [7:0] target_frog;
    reg match_found;

    // Maximum steps to prevent infinite loops
    localparam [16:0] MAX_STEPS = 17'd100000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cmd_out <= 8'd0;
            cmd_valid <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;
            step_count <= 17'd0;
            i <= 4'd0;
            j <= 4'd0;
            target_frog <= 8'd0;
            match_found <= 1'b0;

            // Initialize current array
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                current[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cmd_valid <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        busy <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load start_seq into current array
                    integer k;
                    for (k = 0; k < 16; k = k + 1) begin
                        current[k] <= start_seq[k];
                    end
                    i <= 4'd0;
                    step_count <= 17'd0;
                    next_state <= CHECK;
                end

                CHECK: begin
                    if (i == n - 4'd1) begin
                        // Check if we've reached the end
                        next_state <= DONE_STATE;
                    end else begin
                        if (current[i] == target_seq[i]) begin
                            i <= i + 4'd1;
                            next_state <= CHECK;
                        end else begin
                            target_frog <= target_seq[i];
                            j <= i + 4'd1;
                            match_found <= 1'b0;
                            next_state <= FIND_FROG;
                        end
                    end
                end

                FIND_FROG: begin
                    if (j < n && !match_found) begin
                        if (current[j] == target_frog) begin
                            match_found <= 1'b1;
                            next_state <= BUBBLE;
                        end else begin
                            j <= j + 4'd1;
                            next_state <= FIND_FROG;
                        end
                    end else if (match_found) begin
                        next_state <= BUBBLE;
                    end else begin
                        // No match found, move to next position
                        i <= i + 4'd1;
                        next_state <= CHECK;
                    end
                end

                BUBBLE: begin
                    if (j > i) begin
                        // Output the frog ID to proclaim
                        cmd_out <= current[j];
                        cmd_valid <= 1'b1;
                        
                        // Swap current[j] and current[j-1]
                        reg [7:0] temp;
                        temp <= current[j];
                        current[j] <= current[j - 4'd1];
                        current[j - 4'd1] <= temp;
                        
                        j <= j - 4'd1;
                        step_count <= step_count + 17'd1;
                        
                        if (step_count >= MAX_STEPS) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= BUBBLE;
                        end
                    end else begin
                        // Frog is in correct position, move to next
                        i <= i + 4'd1;
                        next_state <= CHECK;
                    end
                end

                DONE_STATE: begin
                    // Check if current matches target
                    reg [15:0] match;
                    integer k;
                    for (k = 0; k < 16; k = k + 1) begin
                        match[k] <= (current[k] == target_seq[k]);
                    end
                    
                    if (&match[0:15]) begin
                        done <= 1'b1;
                    end
                    
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    busy <= 1'b0;
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule
module robot_path_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] target_a,
    input [7:0] target_b,
    input [3:0] cmd_addr,
    input [7:0] cmd_char,
    output reg found,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD_CMD,
        PROCESS,
        CHECK,
        FINISH
    } state_t;

    state_t current_state, next_state;

    // Command storage (8x8-bit)
    reg [7:0] cmd_mem [0:7];

    // Current position and repetition counter
    reg [7:0] curr_x, curr_y;
    reg [3:0] rep_count;

    // Command processing index
    reg [3:0] cmd_index;

    // Load command counter
    reg [3:0] load_count;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            found <= 1'b0;
            done <= 1'b0;
            cmd_index <= 0;
            load_count <= 0;
            rep_count <= 0;
            curr_x <= 0;
            curr_y <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_CMD;
            end
            LOAD_CMD: begin
                if (load_count == 7) next_state = PROCESS;
            end
            PROCESS: begin
                if (found) next_state = FINISH;
                else if (cmd_index == 7 && rep_count == 1) next_state = CHECK;
            end
            CHECK: next_state = FINISH;
            FINISH: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load command logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_count <= 0;
        end else if (current_state == LOAD_CMD && start) begin
            if (load_count < 8) begin
                cmd_mem[load_count] <= cmd_char;
                load_count <= load_count + 1;
            end
        end
    end

    // Process command logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_index <= 0;
            rep_count <= 0;
            curr_x <= 0;
            curr_y <= 0;
        end else if (current_state == PROCESS) begin
            if (cmd_index < 8) begin
                case (cmd_mem[cmd_index])
                    'U': curr_y <= curr_y + 1;
                    'D': curr_y <= curr_y - 1;
                    'L': curr_x <= curr_x - 1;
                    'R': curr_x <= curr_x + 1;
                    default: ; // No change for invalid commands
                endcase
                cmd_index <= cmd_index + 1;
            end else begin
                cmd_index <= 0;
                rep_count <= rep_count + 1;
            end
        end
    end

    // Check if target is reached during processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            found <= 1'b0;
        end else if (current_state == PROCESS) begin
            if (curr_x == target_a && curr_y == target_b) begin
                found <= 1'b1;
            end
        end
    end

    // Check final position
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            found <= 1'b0;
        end else if (current_state == CHECK) begin
            if (curr_x == target_a && curr_y == target_b) begin
                found <= 1'b1;
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (current_state == FINISH) begin
            done <= 1'b1;
        end else if (current_state == IDLE) begin
            done <= 1'b0;
        end
    end

endmodule
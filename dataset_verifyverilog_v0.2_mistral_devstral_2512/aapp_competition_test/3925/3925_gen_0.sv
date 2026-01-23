module zebra_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] char_index,
    input load,
    output reg [7:0] max_len,
    output reg done
);

    // Define states
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal buffer for storing the string (16x8 bits)
    reg [7:0] buffer [0:15];

    // Counters and temporary variables
    reg [4:0] i, j, k;
    reg [4:0] current_len, max_current_len;
    reg [4:0] prefix_len, suffix_len;
    reg [4:0] load_counter;
    reg [4:0] process_counter;
    reg [4:0] wrap_check;
    reg [4:0] temp_max_len;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_len <= 8'd0;
            done <= 1'b0;
            load_counter <= 5'd0;
            process_counter <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            current_len <= 5'd0;
            max_current_len <= 5'd0;
            prefix_len <= 5'd0;
            suffix_len <= 5'd0;
            wrap_check <= 5'd0;
            temp_max_len <= 5'd0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                if (load_counter == 5'd16) next_state = PROCESS;
            end
            PROCESS: begin
                if (process_counter == 5'd16) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 5'd0;
        end else if (current_state == LOAD) begin
            if (load && (char_index < 5'd16)) begin
                buffer[char_index] <= char_in;
                load_counter <= load_counter + 1'b1;
            end
        end
    end

    // Process state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            process_counter <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            current_len <= 5'd0;
            max_current_len <= 5'd0;
            prefix_len <= 5'd0;
            suffix_len <= 5'd0;
            wrap_check <= 5'd0;
            temp_max_len <= 5'd0;
        end else if (current_state == PROCESS) begin
            case (process_counter)
                5'd0: begin
                    // Initialize variables
                    max_current_len <= 5'd1;
                    temp_max_len <= 5'd1;
                    i <= 5'd1;
                    j <= 5'd0;
                    k <= 5'd0;
                    current_len <= 5'd1;
                    prefix_len <= 5'd1;
                    suffix_len <= 5'd1;
                    wrap_check <= 5'd0;
                end
                5'd1: begin
                    // Check if buffer[0] != buffer[15]
                    if (buffer[0] != buffer[15]) wrap_check <= 5'd1;
                    else wrap_check <= 5'd0;
                end
                5'd2: begin
                    // Calculate prefix length
                    if (i < 5'd16 && (buffer[i] != buffer[i-1])) begin
                        prefix_len <= prefix_len + 1'b1;
                        i <= i + 1'b1;
                    end else begin
                        i <= 5'd0;
                    end
                end
                5'd3: begin
                    // Calculate suffix length
                    if (j < 5'd16 && (buffer[15-j] != buffer[16-j])) begin
                        suffix_len <= suffix_len + 1'b1;
                        j <= j + 1'b1;
                    end else begin
                        j <= 5'd0;
                    end
                end
                5'd4: begin
                    // Calculate max alternating substring
                    if (k < 5'd16) begin
                        if (buffer[k] != buffer[k-1]) begin
                            current_len <= current_len + 1'b1;
                            if (current_len > max_current_len) max_current_len <= current_len;
                        end else begin
                            current_len <= 5'd1;
                        end
                        k <= k + 1'b1;
                    end
                end
                5'd5: begin
                    // Determine final max_len
                    if (wrap_check && (prefix_len + suffix_len) > max_current_len) begin
                        temp_max_len <= prefix_len + suffix_len;
                    end else begin
                        temp_max_len <= max_current_len;
                    end
                    // Cap at 16
                    if (temp_max_len > 5'd16) temp_max_len <= 5'd16;
                    max_len <= temp_max_len;
                end
                default: begin
                    process_counter <= process_counter + 1'b1;
                end
            endcase
        end
    end

    // Done state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (current_state == DONE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule
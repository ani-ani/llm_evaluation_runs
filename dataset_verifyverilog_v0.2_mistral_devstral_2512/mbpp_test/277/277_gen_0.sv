module dict_filter (
    input clk,
    input rst_n,
    input start,
    input [7:0] threshold,
    input [3:0] num_entries,
    input [3:0] key_0, key_1, key_2, key_3,
    input [7:0] val_0, val_1, val_2, val_3,
    output reg [59:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COMPARE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [1:0] entry_counter;
    reg [3:0] valid_count;
    reg [3:0] valid_keys [0:3];
    reg [7:0] valid_vals [0:3];

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            entry_counter <= 0;
            valid_count <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = COMPARE;
            end
            COMPARE: begin
                if (entry_counter == num_entries - 1) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            entry_counter <= 0;
            valid_count <= 0;
            for (int i = 0; i < 4; i++) begin
                valid_keys[i] <= 0;
                valid_vals[i] <= 0;
            end
        end else if (current_state == COMPARE) begin
            // Process current entry
            case (entry_counter)
                0: begin
                    if (val_0 >= threshold) begin
                        valid_keys[valid_count] <= key_0;
                        valid_vals[valid_count] <= val_0;
                        valid_count <= valid_count + 1;
                    end
                end
                1: begin
                    if (val_1 >= threshold) begin
                        valid_keys[valid_count] <= key_1;
                        valid_vals[valid_count] <= val_1;
                        valid_count <= valid_count + 1;
                    end
                end
                2: begin
                    if (val_2 >= threshold) begin
                        valid_keys[valid_count] <= key_2;
                        valid_vals[valid_count] <= val_2;
                        valid_count <= valid_count + 1;
                    end
                end
                3: begin
                    if (val_3 >= threshold) begin
                        valid_keys[valid_count] <= key_3;
                        valid_vals[valid_count] <= val_3;
                        valid_count <= valid_count + 1;
                    end
                end
            endcase
            entry_counter <= entry_counter + 1;
        end
    end

    // Output packing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else if (current_state == DONE) begin
            // Pack the result
            result[59:56] = valid_count;
            for (int i = 0; i < 4; i++) begin
                if (i < valid_count) begin
                    result[55 - 16*i : 52 - 16*i] = valid_keys[i];
                    result[47 - 16*i : 40 - 16*i] = valid_vals[i];
                end else begin
                    result[55 - 16*i : 52 - 16*i] = 0;
                    result[47 - 16*i : 40 - 16*i] = 0;
                end
            end
            done <= 1;
        end else if (start) begin
            done <= 0;
        end
    end

endmodule
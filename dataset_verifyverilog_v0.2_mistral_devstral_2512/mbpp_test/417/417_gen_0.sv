module tuple_grouping (
    input clk,
    input rst_n,
    input start,
    input [1:0] tuple_first [0:3],
    input [1:0] tuple_second [0:3],
    output reg [1:0] group_first [0:3],
    output reg [1:0] group_data [0:15],
    output reg [2:0] group_size [0:3],
    output reg [1:0] num_groups,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        FIND_UNIQUE,
        COLLECT_DATA,
        FORMAT_OUTPUT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [1:0] unique_firsts [0:3];
    reg [3:0] unique_count;
    reg [1:0] current_group;
    reg [3:0] data_offset;
    reg [3:0] cycle_count;

    // Reset all outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            num_groups <= 3'b0;
            for (int i = 0; i < 4; i++) begin
                group_first[i] <= 2'b0;
                group_size[i] <= 3'b0;
            end
            for (int i = 0; i < 16; i++) begin
                group_data[i] <= 2'b0;
            end
            unique_count <= 4'b0;
            current_group <= 2'b0;
            data_offset <= 4'b0;
            cycle_count <= 4'b0;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state <= FIND_UNIQUE;
                        cycle_count <= 4'b0;
                        unique_count <= 4'b0;
                        current_group <= 2'b0;
                        data_offset <= 4'b0;
                        done <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FIND_UNIQUE: begin
                    if (cycle_count == 4'd3) begin
                        next_state <= COLLECT_DATA;
                        cycle_count <= 4'b0;
                    end else begin
                        next_state <= FIND_UNIQUE;
                        cycle_count <= cycle_count + 1'b1;
                    end
                end

                COLLECT_DATA: begin
                    if (cycle_count == 4'd3) begin
                        next_state <= FORMAT_OUTPUT;
                        cycle_count <= 4'b0;
                    end else begin
                        next_state <= COLLECT_DATA;
                        cycle_count <= cycle_count + 1'b1;
                    end
                end

                FORMAT_OUTPUT: begin
                    if (cycle_count == 4'd1) begin
                        next_state <= DONE;
                        cycle_count <= 4'b0;
                    end else begin
                        next_state <= FORMAT_OUTPUT;
                        cycle_count <= cycle_count + 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Find unique first elements
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4; i++) begin
                unique_firsts[i] <= 2'b0;
            end
        end else if (current_state == FIND_UNIQUE && cycle_count == 4'd0) begin
            reg [1:0] temp_unique [0:3];
            reg [3:0] temp_count = 4'b0;

            // Initialize temp_unique
            for (int i = 0; i < 4; i++) begin
                temp_unique[i] <= 2'b0;
            end

            // Find unique first elements
            for (int i = 0; i < 4; i++) begin
                reg found = 1'b0;
                for (int j = 0; j < temp_count; j++) begin
                    if (tuple_first[i] == temp_unique[j]) begin
                        found = 1'b1;
                    end
                end
                if (!found && tuple_first[i] != 2'b0) begin
                    temp_unique[temp_count] <= tuple_first[i];
                    temp_count <= temp_count + 1'b1;
                end
            end

            // Store results
            unique_count <= temp_count;
            for (int i = 0; i < 4; i++) begin
                unique_firsts[i] <= temp_unique[i];
            end
        end
    end

    // Collect data for each group
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                group_data[i] <= 2'b0;
            end
            for (int i = 0; i < 4; i++) begin
                group_size[i] <= 3'b0;
            end
        end else if (current_state == COLLECT_DATA && cycle_count == 4'd0) begin
            reg [2:0] size [0:3];
            reg [1:0] data [0:15];
            reg [3:0] offset = 4'b0;

            // Initialize
            for (int i = 0; i < 4; i++) begin
                size[i] <= 3'b0;
            end
            for (int i = 0; i < 16; i++) begin
                data[i] <= 2'b0;
            end

            // Collect data for each unique first
            for (int i = 0; i < unique_count; i++) begin
                reg [2:0] count = 3'b0;
                for (int j = 0; j < 4; j++) begin
                    if (tuple_first[j] == unique_firsts[i]) begin
                        data[offset] <= tuple_second[j];
                        offset <= offset + 1'b1;
                        count <= count + 1'b1;
                    end
                end
                size[i] <= count;
            end

            // Store results
            for (int i = 0; i < 16; i++) begin
                group_data[i] <= data[i];
            end
            for (int i = 0; i < 4; i++) begin
                group_size[i] <= size[i];
            end
        end
    end

    // Format output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_groups <= 3'b0;
            for (int i = 0; i < 4; i++) begin
                group_first[i] <= 2'b0;
            end
        end else if (current_state == FORMAT_OUTPUT && cycle_count == 4'd0) begin
            num_groups <= unique_count;
            for (int i = 0; i < 4; i++) begin
                group_first[i] <= unique_firsts[i];
            end
        end
    end

endmodule
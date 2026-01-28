module group_validator(
    input clk,
    input rst_n,
    input start,
    input [255:0] adj,
    input [3:0] n,
    input [3:0] p,
    input [3:0] q,
    output reg valid,
    output reg done,
    output reg [63:0] partition,
    output reg [3:0] group_count,
    output reg [255:0] groups
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_PARTITION = 3'd1;
    localparam [2:0] UPDATE = 3'd2;
    localparam [2:0] VALIDATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] partition_counter;
    reg [63:0] current_partition;
    reg [3:0] current_group_count;
    reg [255:0] current_groups;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd100000;

    // Internal signals for validation
    reg [3:0] group_sizes [0:15];
    reg [3:0] cross_edges;
    reg partition_valid;
    reg [3:0] i, j, k;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            partition_counter <= 16'd0;
            current_partition <= 64'd0;
            current_group_count <= 4'd0;
            current_groups <= 256'd0;
            valid <= 1'b0;
            done <= 1'b0;
            partition <= 64'd0;
            group_count <= 4'd0;
            groups <= 256'd0;
            cycle_count <= 4'd0;
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
                    next_state = CHECK_PARTITION;
                end
            end
            CHECK_PARTITION: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                next_state = VALIDATE;
            end
            VALIDATE: begin
                if (partition_valid) begin
                    next_state = DONE_STATE;
                end else if (partition_counter == (1 << n) - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CHECK_PARTITION;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Partition counter increment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            partition_counter <= 16'd0;
        end else if (state == CHECK_PARTITION) begin
            partition_counter <= partition_counter + 16'd1;
        end
    end

    // Generate current partition
    always @(*) begin
        for (i = 0; i < 16; i = i + 1) begin
            if (i < n) begin
                current_partition[i*4 +: 4] = partition_counter[i];
            end else begin
                current_partition[i*4 +: 4] = 4'd0;
            end
        end
    end

    // Validate partition
    always @(*) begin
        // Initialize group sizes
        for (i = 0; i < 16; i = i + 1) begin
            group_sizes[i] = 4'd0;
        end

        // Count group sizes
        for (i = 0; i < n; i = i + 1) begin
            group_sizes[current_partition[i*4 +: 4]] = group_sizes[current_partition[i*4 +: 4]] + 4'd1;
        end

        // Check group size constraint
        partition_valid = 1'b1;
        for (i = 0; i < 16; i = i + 1) begin
            if (group_sizes[i] > p && group_sizes[i] != 4'd0) begin
                partition_valid = 1'b0;
            end
        end

        // Count cross edges
        if (partition_valid) begin
            cross_edges = 4'd0;
            for (i = 0; i < n; i = i + 1) begin
                for (j = i + 1; j < n; j = j + 1) begin
                    if (current_partition[i*4 +: 4] != current_partition[j*4 +: 4] && adj[i*16 + j]) begin
                        cross_edges = cross_edges + 4'd1;
                    end
                end
            end

            if (cross_edges > q) begin
                partition_valid = 1'b0;
            end
        end
    end

    // Update current groups
    always @(*) begin
        // Clear current groups
        current_groups = 256'd0;
        current_group_count = 4'd0;

        // Set group masks
        for (i = 0; i < n; i = i + 1) begin
            current_groups[current_partition[i*4 +: 4]*16 + i] = 1'b1;
        end

        // Count groups
        for (i = 0; i < 16; i = i + 1) begin
            if (group_sizes[i] != 4'd0) begin
                current_group_count = current_group_count + 4'd1;
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                end
                CHECK_PARTITION: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                end
                UPDATE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                end
                VALIDATE: begin
                    if (partition_valid) begin
                        partition <= current_partition;
                        group_count <= current_group_count;
                        groups <= current_groups;
                        valid <= 1'b1;
                    end
                    done <= 1'b0;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                default: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Cycle counter for timeout
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 4'd0;
        end else if (state != IDLE && state != DONE_STATE) begin
            if (cycle_count == MAX_CYCLES) begin
                cycle_count <= 4'd0;
            end else begin
                cycle_count <= cycle_count + 4'd1;
            end
        end
    end

endmodule
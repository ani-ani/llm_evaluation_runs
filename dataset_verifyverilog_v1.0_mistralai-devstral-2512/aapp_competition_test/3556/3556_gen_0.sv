module EmployeeHierarchy(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire data_in_valid,
    input wire [31:0] data_bus,
    input wire [15:0] query_id,
    input wire query_start,
    output reg done,
    output reg [15:0] result_boss,
    output reg [15:0] result_sub_count,
    output reg result_valid,
    output reg busy
);

    // Parameters
    localparam [11:0] MAX_EMP = 12'd1000;
    localparam [4:0] MAX_QUERIES = 5'd100;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] SORT = 2'd2;
    localparam [1:0] BUILD = 2'd3;
    localparam [1:0] QUERY = 2'd4;

    // State and control signals
    reg [1:0] state;
    reg [11:0] emp_count;
    reg [4:0] query_count;
    reg [11:0] i, j, k;
    reg [11:0] temp;
    reg [11:0] stack_ptr;
    reg [11:0] stack [0:1023];

    // Employee data storage
    reg [15:0] ids [0:999];
    reg [23:0] salaries [0:999];
    reg [23:0] heights [0:999];
    reg [11:0] sorted_indices [0:999];
    reg [15:0] parent [0:999];
    reg [15:0] sub_count [0:999];

    // Sorting variables
    reg [11:0] sort_i, sort_j;
    reg [11:0] min_idx;

    // Query processing
    reg [15:0] current_query_id;
    reg [15:0] query_result_boss;
    reg [15:0] query_result_sub_count;

    // FSM for main control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            emp_count <= 12'd0;
            query_count <= 5'd0;
            i <= 12'd0;
            j <= 12'd0;
            k <= 12'd0;
            temp <= 12'd0;
            stack_ptr <= 12'd0;
            sort_i <= 12'd0;
            sort_j <= 12'd0;
            min_idx <= 12'd0;
            current_query_id <= 16'd0;
            query_result_boss <= 16'd0;
            query_result_sub_count <= 16'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            busy <= 1'b0;

            // Initialize arrays
            for (temp = 0; temp < MAX_EMP; temp = temp + 1) begin
                ids[temp] <= 16'd0;
                salaries[temp] <= 24'd0;
                heights[temp] <= 24'd0;
                sorted_indices[temp] <= 12'd0;
                parent[temp] <= 16'd0;
                sub_count[temp] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        emp_count <= 12'd0;
                        busy <= 1'b1;
                    end
                end

                LOAD: begin
                    if (data_in_valid) begin
                        if (data_bus[31:30] == 2'd3) begin
                            state <= SORT;
                            i <= 12'd0;
                            sort_i <= 12'd0;
                        end else begin
                            case (data_bus[31:30])
                                2'd0: ids[emp_count] <= data_bus[29:16];
                                2'd1: salaries[emp_count] <= data_bus[23:0];
                                2'd2: heights[emp_count] <= data_bus[23:0];
                            endcase
                            emp_count <= emp_count + 12'd1;
                        end
                    end
                end

                SORT: begin
                    if (sort_i < emp_count) begin
                        min_idx <= sort_i;
                        for (sort_j = sort_i + 12'd1; sort_j < emp_count; sort_j = sort_j + 12'd1) begin
                            if (salaries[sort_j] < salaries[min_idx]) begin
                                min_idx <= sort_j;
                            end
                        end
                        temp <= sorted_indices[sort_i];
                        sorted_indices[sort_i] <= sorted_indices[min_idx];
                        sorted_indices[min_idx] <= temp;
                        sort_i <= sort_i + 12'd1;
                    end else begin
                        state <= BUILD;
                        i <= 12'd0;
                        j <= 12'd0;
                    end
                end

                BUILD: begin
                    if (i < emp_count - 12'd1) begin
                        if (j < emp_count) begin
                            if (j > i && salaries[sorted_indices[j]] > salaries[sorted_indices[i]] && 
                                heights[sorted_indices[j]] >= heights[sorted_indices[i]]) begin
                                parent[sorted_indices[i]] <= ids[sorted_indices[j]];
                                j <= emp_count;
                            end else begin
                                j <= j + 12'd1;
                            end
                        end else begin
                            i <= i + 12'd1;
                            j <= 12'd0;
                        end
                    end else begin
                        // Compute sub_count using stack-based DFS
                        stack_ptr <= 12'd0;
                        stack[stack_ptr] <= emp_count - 12'd1;
                        stack_ptr <= stack_ptr + 12'd1;
                        
                        while (stack_ptr > 12'd0) begin
                            stack_ptr <= stack_ptr - 12'd1;
                            temp <= stack[stack_ptr];
                            sub_count[temp] <= 16'd1;
                            
                            for (k = 12'd0; k < emp_count; k = k + 12'd1) begin
                                if (parent[ids[k]] == ids[temp]) begin
                                    stack[stack_ptr] <= k;
                                    stack_ptr <= stack_ptr + 12'd1;
                                end
                            end
                        end
                        
                        state <= QUERY;
                        done <= 1'b1;
                        busy <= 1'b0;
                    end
                end

                QUERY: begin
                    if (query_start) begin
                        current_query_id <= query_id;
                        query_result_boss <= 16'd0;
                        query_result_sub_count <= 16'd0;
                        
                        for (i = 12'd0; i < emp_count; i = i + 12'd1) begin
                            if (ids[i] == current_query_id) begin
                                query_result_boss <= parent[i];
                                query_result_sub_count <= sub_count[i];
                            end
                        end
                        
                        result_boss <= query_result_boss;
                        result_sub_count <= query_result_sub_count;
                        result_valid <= 1'b1;
                    end else begin
                        result_valid <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Initialize sorted_indices
    integer init_i;
    initial begin
        for (init_i = 0; init_i < MAX_EMP; init_i = init_i + 1) begin
            sorted_indices[init_i] = init_i;
        end
    end

endmodule
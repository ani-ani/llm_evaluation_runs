module EulerianDP (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] m_in,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CHECK   = 3'd1;
    localparam [2:0] INIT    = 3'd2;
    localparam [2:0] NEXT_ROW = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] current_n;      // Current n being computed (0 to n_in)
    reg [3:0] current_m;      // Current m index for row computation
    reg [3:0] target_n;       // Target n from input
    reg [3:0] target_m;       // Target m from input
    reg [15:0] prev_row [0:7]; // Storage for row n-1
    reg [15:0] curr_row [0:7]; // Storage for row n
    reg [1:0] init_counter;    // Counter for initialization
    reg [3:0] compute_counter; // Counter for row computation
    reg edge_case_flag;        // Flag for edge cases (m >= n)
    reg [15:0] edge_case_result; // Result for edge cases
    integer i;                 // Loop variable

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? CHECK : IDLE;
            CHECK: begin
                if (n_in == 4'd0 || edge_case_flag) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = INIT;
                end
            end
            INIT: begin
                if (init_counter == 2'd2) begin
                    next_state = NEXT_ROW;
                end else begin
                    next_state = INIT;
                end
            end
            NEXT_ROW: begin
                if (current_n == target_n) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = NEXT_ROW;
                end
            end
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_n <= 4'd0;
            current_m <= 4'd0;
            target_n <= 4'd0;
            target_m <= 4'd0;
            edge_case_flag <= 1'b0;
            edge_case_result <= 16'd0;
            init_counter <= 2'd0;
            compute_counter <= 4'd0;
            // Initialize arrays to 0
            for (i = 0; i < 8; i = i + 1) begin
                prev_row[i] <= 16'd0;
                curr_row[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    init_counter <= 2'd0;
                    compute_counter <= 4'd0;
                    edge_case_flag <= 1'b0;
                end

                CHECK: begin
                    target_n <= n_in;
                    target_m <= m_in;
                    
                    // Check edge cases
                    if (n_in == 4'd0) begin
                        edge_case_flag <= 1'b1;
                        edge_case_result <= 16'd0;
                    end else if (m_in >= n_in) begin
                        edge_case_flag <= 1'b1;
                        edge_case_result <= 16'd0;
                    end else if (m_in == 4'd0) begin
                        edge_case_flag <= 1'b1;
                        edge_case_result <= 16'd1;
                    end else begin
                        edge_case_flag <= 1'b0;
                    end
                end

                INIT: begin
                    // Initialize row n=0: a(0,m) = 0 for all m
                    // First iteration: initialize prev_row
                    // Second iteration: set curr_row for n=1
                    if (init_counter == 2'd0) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            prev_row[i] <= 16'd0;
                        end
                        current_n <= 4'd1;
                        init_counter <= 2'd1;
                    end else begin
                        // Compute a(1,m) values
                        // a(1,0) = 1, a(1,1) = 0
                        // For m >= 2: 0
                        curr_row[0] <= 16'd1;
                        curr_row[1] <= 16'd0;
                        for (i = 2; i < 8; i = i + 1) begin
                            curr_row[i] <= 16'd0;
                        end
                        init_counter <= 2'd2;
                    end
                end

                NEXT_ROW: begin
                    // Compute current row from previous row
                    // a(n,m) = (n-m)*a(n-1,m-1) + (m+1)*a(n-1,m)
                    if (compute_counter <= current_n) begin
                        if (compute_counter == 4'd0) begin
                            // a(n,0) = 1
                            curr_row[0] <= 16'd1;
                        end else if (compute_counter < current_n) begin
                            // Compute a(n,m) for 0 < m < n
                            // Load previous values
                            curr_row[compute_counter] <= 
                                (current_n - compute_counter) * prev_row[compute_counter - 4'd1] +
                                (compute_counter + 4'd1) * prev_row[compute_counter];
                        end else begin
                            // compute_counter == current_n: a(n,n) = 0
                            curr_row[current_n] <= 16'd0;
                        end
                        
                        compute_counter <= compute_counter + 4'd1;
                    end else begin
                        // Row computation complete, copy to prev_row
                        for (i = 0; i < 8; i = i + 1) begin
                            prev_row[i] <= curr_row[i];
                        end
                        current_n <= current_n + 4'd1;
                        compute_counter <= 4'd0;
                    end
                end

                COMPLETE: begin
                    // Present result
                    if (edge_case_flag) begin
                        result <= edge_case_result;
                    end else begin
                        result <= curr_row[target_m];
                    end
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
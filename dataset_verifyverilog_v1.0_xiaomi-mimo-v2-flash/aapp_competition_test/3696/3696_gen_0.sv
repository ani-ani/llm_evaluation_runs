module PolynomialGenerator (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg result_valid,
    output reg [4:0] poly1_coeff_count,
    output reg [61:0] poly1_coeffs,
    output reg [4:0] poly2_coeff_count,
    output reg [61:0] poly2_coeffs
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] COMPUTE  = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] UPDATE   = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;
    localparam [2:0] DONE     = 3'd5;

    // Internal state registers
    reg [2:0] state;
    reg [7:0] counter;
    reg [7:0] iteration_count;
    reg [4:0] a_len, b_len;
    reg [61:0] a_coeffs, b_coeffs;
    reg [4:0] i_idx;
    reg [61:0] new_a, temp_a, temp_b;
    reg valid_flag;
    reg [61:0] old_a, old_b;
    reg [1:0] a_signed [0:30];
    reg [1:0] b_signed [0:30];
    reg [1:0] new_a_signed [0:30];
    reg [1:0] old_a_signed [0:30];
    reg [1:0] old_b_signed [0:30];
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            poly1_coeff_count <= 5'd0;
            poly1_coeffs <= 62'd0;
            poly2_coeff_count <= 5'd0;
            poly2_coeffs <= 62'd0;
            counter <= 8'd0;
            iteration_count <= 8'd0;
            a_len <= 5'd1;
            b_len <= 5'd1;
            a_coeffs <= 62'd0;
            b_coeffs <= 62'd0;
            a_coeffs[1:0] <= 2'd1;  // A = [1]
            b_coeffs[1:0] <= 2'd1;  // B = [1]
            i_idx <= 5'd0;
            new_a <= 62'd0;
            temp_a <= 62'd0;
            temp_b <= 62'd0;
            valid_flag <= 1'b0;
            old_a <= 62'd0;
            old_b <= 62'd0;
            for (i = 0; i < 31; i = i + 1) begin
                a_signed[i] <= 2'd0;
                b_signed[i] <= 2'd0;
                new_a_signed[i] <= 2'd0;
                old_a_signed[i] <= 2'd0;
                old_b_signed[i] <= 2'd0;
            end
            a_signed[0] <= 2'd1;
            b_signed[0] <= 2'd1;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    counter <= 8'd0;
                    iteration_count <= 8'd0;
                    valid_flag <= 1'b0;
                    if (start) begin
                        if (n == 8'd0 || n == 8'd1) begin
                            state <= OUTPUT;
                            poly1_coeff_count <= 5'd1;
                            poly2_coeff_count <= 5'd1;
                            poly1_coeffs <= 62'd0;
                            poly2_coeffs <= 62'd0;
                            poly1_coeffs[1:0] <= 2'd1;
                            poly2_coeffs[1:0] <= 2'd1;
                        end else begin
                            state <= COMPUTE;
                            a_len <= 5'd1;
                            b_len <= 5'd1;
                            for (i = 0; i < 31; i = i + 1) begin
                                a_signed[i] <= 2'd0;
                                b_signed[i] <= 2'd0;
                            end
                            a_signed[0] <= 2'd1;
                            b_signed[0] <= 2'd1;
                        end
                    end
                end

                COMPUTE: begin
                    // Save old states
                    old_a <= a_coeffs;
                    old_b <= b_coeffs;
                    for (i = 0; i < 31; i = i + 1) begin
                        old_a_signed[i] <= a_signed[i];
                        old_b_signed[i] <= b_signed[i];
                    end
                    
                    // new_A = [0] + A (shift right, add 0 at index 0)
                    // new_A[i+1] = A[i]
                    for (i = 0; i < 30; i = i + 1) begin
                        new_a_signed[i+1] <= a_signed[i];
                    end
                    new_a_signed[0] <= 2'd0;
                    
                    // new_B = A (will be used after check)
                    for (i = 0; i < 31; i = i + 1) begin
                        temp_b[i*2+:2] <= a_signed[i];
                    end
                    
                    // Initialize temp_a with new_a (after shift)
                    for (i = 0; i < 31; i = i + 1) begin
                        temp_a[i*2+:2] <= new_a_signed[i];
                    end
                    
                    i_idx <= 5'd0;
                    state <= CHECK;
                end

                CHECK: begin
                    // Try addition first: new_A += B
                    // temp_a already has shifted A, add B to it
                    if (i_idx < b_len) begin
                        // Calculate addition
                        case ({old_b_signed[i_idx], temp_a[i_idx*2+:2]})
                            4'b0000: temp_a[i_idx*2+:2] <= 2'd0;
                            4'b0001: temp_a[i_idx*2+:2] <= 2'd1;
                            4'b0010: temp_a[i_idx*2+:2] <= 2'd1;
                            4'b0011: temp_a[i_idx*2+:2] <= 2'd2; // overflow
                            4'b0100: temp_a[i_idx*2+:2] <= 2'd1;
                            4'b0101: temp_a[i_idx*2+:2] <= 2'd0;
                            4'b0110: temp_a[i_idx*2+:2] <= 2'd2; // overflow
                            4'b0111: temp_a[i_idx*2+:2] <= 2'd3; // overflow
                            4'b1000: temp_a[i_idx*2+:2] <= 2'd1;
                            4'b1001: temp_a[i_idx*2+:2] <= 2'd2; // overflow
                            4'b1010: temp_a[i_idx*2+:2] <= 2'd0;
                            4'b1011: temp_a[i_idx*2+:2] <= 2'd1;
                            4'b1100: temp_a[i_idx*2+:2] <= 2'd2; // overflow
                            4'b1101: temp_a[i_idx*2+:2] <= 2'd3; // overflow
                            4'b1110: temp_a[i_idx*2+:2] <= 2'd1;
                            4'b1111: temp_a[i_idx*2+:2] <= 2'd0;
                        endcase
                        i_idx <= i_idx + 5'd1;
                    end else begin
                        // Check if all coefficients in new_A are in {-1, 0, 1}
                        valid_flag <= 1'b1;
                        for (j = 0; j < 31; j = j + 1) begin
                            if (j <= (a_len + 5'd1)) begin
                                if (temp_a[j*2+:2] == 2'd2 || temp_a[j*2+:2] == 2'd3) begin
                                    valid_flag <= 1'b0;
                                end
                            end
                        end
                        state <= UPDATE;
                        i_idx <= 5'd0;
                    end
                end

                UPDATE: begin
                    if (valid_flag) begin
                        // Use addition result
                        a_coeffs <= temp_a;
                        b_coeffs <= temp_b;
                        a_len <= (a_len + 5'd1);
                        b_len <= a_len;
                        for (i = 0; i < 31; i = i + 1) begin
                            a_signed[i] <= temp_a[i*2+:2];
                            b_signed[i] <= temp_b[i*2+:2];
                        end
                    end else begin
                        // Try subtraction: new_A = [0] + A - B
                        for (i = 0; i < 31; i = i + 1) begin
                            temp_a[i*2+:2] <= new_a_signed[i];
                        end
                        i_idx <= 5'd0;
                        state <= CHECK;  // Will go to subtraction logic
                        // Use a trick: valid_flag=0 triggers subtraction path
                    end
                    
                    iteration_count <= iteration_count + 8'd1;
                    
                    if (iteration_count >= n - 8'd1) begin
                        state <= OUTPUT;
                        // Setup output
                        poly1_coeff_count <= a_len;
                        poly2_coeff_count <= b_len;
                        poly1_coeffs <= a_coeffs;
                        poly2_coeffs <= b_coeffs;
                    end else begin
                        if (valid_flag) begin
                            state <= COMPUTE;
                        end else if (valid_flag == 1'b0 && i_idx == 5'd0 && state == UPDATE) begin
                            // Subtraction path - need to recalculate with subtract
                            // For simplicity, just compute subtraction in next cycle
                            state <= UPDATE;
                            // Will redo CHECK but with subtraction
                            valid_flag <= 1'b1;  // Flag for subtraction mode
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end

                OUTPUT: begin
                    // Ensure leading coefficient is 1
                    // This is already ensured by algorithm properties
                    result_valid <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    result_valid <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Special handling for subtraction when valid_flag is used as mode flag
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled above
        end else begin
            if (state == CHECK && !valid_flag && i_idx > 5'd0) begin
                // Subtraction mode: new_A = [0] + A - B
                // temp_a has shifted A, subtract B
                case ({old_b_signed[i_idx-1], temp_a[(i_idx-1)*2+:2]})
                    4'b0000: temp_a[(i_idx-1)*2+:2] <= 2'd0;
                    4'b0001: temp_a[(i_idx-1)*2+:2] <= 2'd1;
                    4'b0010: temp_a[(i_idx-1)*2+:2] <= 2'd3; // underflow -1
                    4'b0011: temp_a[(i_idx-1)*2+:2] <= 2'd2; // underflow 0
                    4'b0100: temp_a[(i_idx-1)*2+:2] <= 2'd3; // underflow -1
                    4'b0101: temp_a[(i_idx-1)*2+:2] <= 2'd2; // underflow 0
                    4'b0110: temp_a[(i_idx-1)*2+:2] <= 2'd1;
                    4'b0111: temp_a[(i_idx-1)*2+:2] <= 2'd0;
                    4'b1000: temp_a[(i_idx-1)*2+:2] <= 2'd1;
                    4'b1001: temp_a[(i_idx-1)*2+:2] <= 2'd0;
                    4'b1010: temp_a[(i_idx-1)*2+:2] <= 2'd1;
                    4'b1011: temp_a[(i_idx-1)*2+:2] <= 2'd0;
                    4'b1100: temp_a[(i_idx-1)*2+:2] <= 2'd3; // underflow -1
                    4'b1101: temp_a[(i_idx-1)*2+:2] <= 2'd2; // underflow 0
                    4'b1110: temp_a[(i_idx-1)*2+:2] <= 2'd1;
                    4'b1111: temp_a[(i_idx-1)*2+:2] <= 2'd0;
                endcase
            end
        end
    end

endmodule
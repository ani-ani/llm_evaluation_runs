module FunctionDecomposition (
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [5:0] f_in,
    input f_valid,
    output reg result_valid,
    output reg possible,
    output reg [5:0] m,
    output reg [5:0] g_out_idx,
    output reg [5:0] h_out_idx,
    output reg g_read_en,
    output reg h_read_en
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] READ_F     = 3'd1;
    localparam [2:0] VERIFY     = 3'd2;
    localparam [2:0] CONSTRUCT  = 3'd3;
    localparam [2:0] OUTPUT_G   = 3'd4;
    localparam [2:0] OUTPUT_H   = 3'd5;
    localparam [2:0] DONE       = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] f_reg [0:63];  // f[1..n] stored at indices 0..63
    reg [5:0] g_reg [0:63];  // g[1..n]
    reg [5:0] h_reg [0:63];  // h[1..m]
    reg [5:0] image_reg [0:63];  // Distinct image values
    reg [5:0] image_count;
    reg [5:0] counter;  // General purpose counter
    reg [5:0] n_reg;
    reg is_possible;
    reg [5:0] f_idx;  // For READ_F state
    reg [5:0] verify_idx;  // For VERIFY state
    reg [5:0] construct_idx;  // For CONSTRUCT state
    reg [5:0] output_idx;  // For OUTPUT states

    integer i;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = READ_F;
            end
            READ_F: begin
                if (f_idx >= n_reg && f_valid) next_state = VERIFY;
            end
            VERIFY: begin
                if (verify_idx > n_reg) begin
                    if (is_possible) next_state = CONSTRUCT;
                    else next_state = DONE;
                end
            end
            CONSTRUCT: begin
                if (construct_idx > n_reg) next_state = OUTPUT_G;
            end
            OUTPUT_G: begin
                if (output_idx > n_reg) next_state = OUTPUT_H;
            end
            OUTPUT_H: begin
                if (output_idx > image_count) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            possible <= 1'b0;
            m <= 6'd0;
            g_out_idx <= 6'd0;
            h_out_idx <= 6'd0;
            g_read_en <= 1'b0;
            h_read_en <= 1'b0;
            f_idx <= 6'd0;
            verify_idx <= 6'd0;
            construct_idx <= 6'd0;
            output_idx <= 6'd0;
            counter <= 6'd0;
            image_count <= 6'd0;
            is_possible <= 1'b1;
            n_reg <= 6'd0;
            // Clear arrays
            for (i = 0; i < 64; i = i + 1) begin
                f_reg[i] <= 6'd0;
                g_reg[i] <= 6'd0;
                h_reg[i] <= 6'd0;
                image_reg[i] <= 6'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    possible <= 1'b0;
                    m <= 6'd0;
                    g_read_en <= 1'b0;
                    h_read_en <= 1'b0;
                    g_out_idx <= 6'd0;
                    h_out_idx <= 6'd0;
                    f_idx <= 6'd0;
                    verify_idx <= 6'd0;
                    construct_idx <= 6'd0;
                    output_idx <= 6'd0;
                    counter <= 6'd0;
                    image_count <= 6'd0;
                    is_possible <= 1'b1;
                    if (start) n_reg <= n;
                end

                READ_F: begin
                    if (f_valid) begin
                        f_reg[f_idx] <= f_in;
                        f_idx <= f_idx + 6'd1;
                    end
                end

                VERIFY: begin
                    if (verify_idx <= n_reg) begin
                        // Check if f(verify_idx) is in the image of f
                        // An element y is in image of f if f(y) == f(y)
                        // We need to check if verify_idx is in the image
                        // i.e., if there exists x such that f(x) = verify_idx
                        // For this, we look through f_reg
                        // But we need f(y) == y for y in image
                        // So y is in image if exists x: f(x) = y
                        // Then check f(y) == y
                        
                        // Check if verify_idx is in image
                        // Scan through f_reg to see if any f(i) == verify_idx
                        // This is done by tracking which indices we've seen
                        // Using image_reg built during VERIFY
                        
                        // Actually, we need to build image set first
                        // Modified approach: during VERIFY we build image set
                        // and check f(y) == y simultaneously
                        
                        // First pass: check if verify_idx is in image
                        // by looking if f(verify_idx) points to verify_idx in f array
                        // Wait, need different logic:
                        // y is in image if exists x: f(x) = y
                        // So we need to check: if y in image, then f(y) must equal y
                        // Build image set, then verify
                        
                        // Simplified: y is in image of f iff f(f_inv(y)) = y
                        // But we don't have f_inv yet
                        // Alternative: y is in image iff exists x: f(x) = y
                        // We can compute this by scanning
                        
                        // Using a flag to track if y is in image
                        reg y_in_image;
                        integer j;
                        y_in_image = 1'b0;
                        for (j = 0; j < 64; j = j + 1) begin
                            if (j < n_reg && f_reg[j] == verify_idx) begin
                                y_in_image = 1'b1;
                            end
                        end
                        
                        if (y_in_image) begin
                            // Check f(y) == y
                            if (f_reg[verify_idx - 6'd1] != verify_idx) begin
                                is_possible <= 1'b0;
                            end
                            // Add to image set if not already
                            reg already_in;
                            already_in = 1'b0;
                            for (j = 0; j < 64; j = j + 1) begin
                                if (image_reg[j] == verify_idx) already_in = 1'b1;
                            end
                            if (!already_in && image_count < 64) begin
                                image_reg[image_count] <= verify_idx;
                                image_count <= image_count + 6'd1;
                            end
                        end
                        verify_idx <= verify_idx + 6'd1;
                    end
                end

                CONSTRUCT: begin
                    // For each i in 1..n, find g[i] = j where h[j] = f(i)
                    if (construct_idx <= n_reg) begin
                        // Find index j such that h[j] = f(construct_idx)
                        // Since h is sorted image values, we can search
                        reg [5:0] f_val;
                        reg [5:0] h_idx;
                        f_val = f_reg[construct_idx - 6'd1];
                        h_idx = 6'd0;
                        for (i = 0; i < 64; i = i + 1) begin
                            if (i < image_count && image_reg[i] == f_val) begin
                                h_idx = i + 6'd1;  // 1-based index
                            end
                        end
                        g_reg[construct_idx - 6'd1] <= h_idx;
                        m <= image_count;
                        construct_idx <= construct_idx + 6'd1;
                    end
                    // Copy image to h_reg
                    if (construct_idx == n_reg + 6'd1) begin
                        for (i = 0; i < 64; i = i + 1) begin
                            if (i < image_count) h_reg[i] <= image_reg[i];
                        end
                    end
                end

                OUTPUT_G: begin
                    g_read_en <= 1'b1;
                    h_read_en <= 1'b0;
                    if (output_idx < n_reg) begin
                        output_idx <= output_idx + 6'd1;
                        g_out_idx <= output_idx + 6'd1;
                    end else begin
                        output_idx <= 6'd1;  // Start h output at index 1
                        g_out_idx <= 6'd0;
                    end
                end

                OUTPUT_H: begin
                    g_read_en <= 1'b0;
                    h_read_en <= 1'b1;
                    if (output_idx <= image_count) begin
                        output_idx <= output_idx + 6'd1;
                        h_out_idx <= output_idx;
                    end
                end

                DONE: begin
                    g_read_en <= 1'b0;
                    h_read_en <= 1'b0;
                    result_valid <= 1'b1;
                    possible <= is_possible;
                end
            endcase
        end
    end

endmodule
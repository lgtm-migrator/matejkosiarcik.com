module.exports = {
    presets: [
        [
            "@babel/preset-env",
            {
                "forceAllTransforms": true,
                "spec": true,
                "useBuiltIns": "usage",
                "corejs": 3,
                "modules": false
            }
        ],
        "@babel/typescript"
    ],
    plugins: [
        "@babel/proposal-class-properties",
        "@babel/proposal-object-rest-spread"
    ]
}

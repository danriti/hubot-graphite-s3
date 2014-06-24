# Description
#   Proxy Graphite images to an AWS S3 bucket.
#
# Configuration:
#   HUBOT_GRAPHITE_S3_TEMP
#   HUBOT_GRAPHITE_S3_BUCKET
#   AWS_SECRET_ACCESS_KEY
#   AWS_ACCESS_KEY_ID
#
# Commands:
#   None
#
# Notes:
#   None
#
# Author:
#   danriti

http = require('http')
fs = require('fs')
crypto = require('crypto')
aws = require('aws-sdk')

S3_AUTHORITY = 'https://s3.amazonaws.com'
TEMP_DIRECTORY = process.env.HUBOT_GRAPHITE_S3_TEMP || '/tmp'
S3_BUCKET = process.env.HUBOT_GRAPHITE_S3_BUCKET

class Image
  constructor: (url) ->
    @url = url
    @key = @hash(url)
    @filePath = @path(@key)
    @s3 = new aws.S3()

  path: (key) ->
    return TEMP_DIRECTORY + '/' + key

  hash: (url) ->
    return crypto.createHash('sha1').update(url).digest('hex') + '.png'

  s3url: () ->
    return S3_AUTHORITY + '/' + S3_BUCKET + '/' + @key

  save: (callback) ->
    self = this
    file = fs.createWriteStream(self.filePath)
    request = http.get self.url, (response) ->
      response.pipe(file)
      file.on 'finish', () ->
        file.close () ->
          callback()
    request.end()

  put: (callback) ->
    self = this
    fs.readFile self.filePath, (err, data) ->
      if err
        throw err
      param =
        Bucket: S3_BUCKET,
        Key: self.key,
        Body: data,
        ContentType: 'image/png'
      self.s3.putObject param, (err, data) ->
        if err
          console.log(err, err.stack)
          callback(err)
        else
          callback(self.s3url())

class Proxy
  constructor: () ->
    @image = null

  request: (url, callback) ->
    self = this
    self.image = new Image url
    self.image.save () ->
      self.image.put (response) ->
        callback(response)

module.exports = (robot) ->

  robot.graphiteProxy = new Proxy
